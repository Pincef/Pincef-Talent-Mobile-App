import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import './models/interview_model.dart';

/// Backend error, already reduced to a message that's safe to show.
class InterviewException implements Exception {
  InterviewException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isConflict => statusCode == 409;
  bool get isPlanBlocked => statusCode == 403;

  factory InterviewException.from(DioException e) {
    final data = e.response?.data;
    String? msg;
    if (data is Map) {
      msg = (data['message'] ?? data['error'])?.toString();
    }
    msg ??= switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Can\'t reach the server. Check your connection.',
      _ => 'Something went wrong. Please try again.',
    };
    return InterviewException(msg, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}

class InterviewRepository {
  InterviewRepository(this._dio);
  final Dio _dio;

  // Matches `app.use('/api/interviews', interviewRouter)`. If your Dio baseUrl
  // already ends in /api this is correct as-is; otherwise use '/api/interviews'.
  static const _base = '/interviews';

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw InterviewException.from(e);
    }
  }

  dynamic _data(Response<dynamic> r) => (r.data as Map)['data'];

  Interview _one(Response<dynamic> r) =>
      Interview.fromJson(Map<String, dynamic>.from(_data(r) as Map));

  List<Interview> _many(Response<dynamic> r) => (_data(r) as List)
      .map((e) => Interview.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  // ----- recruiter: reads --------------------------------------------------

  Future<List<Interview>> listInterviews({
    required DateTime from,
    required DateTime to,
    InterviewStatus? status,
  }) =>
      _guard(() async => _many(await _dio.get(_base, queryParameters: {
            'from': _iso(from),
            'to': _iso(to),
            if (status != null) 'status': status.api,
          })));

  Future<InterviewStats> stats({
    required DateTime weekStart,
    required DateTime weekEnd,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) =>
      _guard(() async {
        final r = await _dio.get('$_base/stats', queryParameters: {
          'weekStart': _iso(weekStart),
          'weekEnd': _iso(weekEnd),
          'dayStart': _iso(dayStart),
          'dayEnd': _iso(dayEnd),
        });
        return InterviewStats.fromJson(
            Map<String, dynamic>.from(_data(r) as Map));
      });

  Future<List<SchedulableApplication>> schedulable() => _guard(() async {
        final r = await _dio.get('$_base/schedulable');
        return (_data(r) as List)
            .map((e) => SchedulableApplication.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  Future<AvailableSlots> slots({
    required String applicationId,
    required DateTime windowStart,
    required DateTime windowEnd,
    required int durationMins,
    String? excludeInterviewId,
  }) =>
      _guard(() async {
        final r = await _dio.get('$_base/slots', queryParameters: {
          'applicationId': applicationId,
          'windowStart': _iso(windowStart),
          'windowEnd': _iso(windowEnd),
          'durationMins': durationMins,
          if (excludeInterviewId != null)
            'excludeInterviewId': excludeInterviewId,
        });
        return AvailableSlots.fromJson(
            Map<String, dynamic>.from(_data(r) as Map));
      });

  // ----- recruiter: mutations ----------------------------------------------

  Future<({Interview interview, bool emailSent})> createInterview(
          CreateInterviewRequest req) =>
      _guard(() async {
        final r = await _dio.post(_base, data: req.toJson());
        final meta = (r.data as Map)['meta'] as Map?;
        return (interview: _one(r), emailSent: meta?['emailSent'] == true);
      });

  /// `emailSent` is null when the timing didn't change (no email is sent).
  Future<({Interview interview, bool? emailSent})> updateInterview(
    String id, {
    String? roundName,
    DateTime? startsAt,
    int? durationMins,
    String? meetingUrl, // null clears it
    String? notes, // null clears it
  }) =>
      _guard(() async {
        final r = await _dio.patch('$_base/$id', data: {
          if (roundName != null) 'roundName': roundName,
          if (startsAt != null) 'startsAt': _iso(startsAt),
          if (durationMins != null) 'durationMins': durationMins,
          'meetingUrl': meetingUrl,
          'notes': notes,
          'tzOffsetMinutes': localOffsetMinutes(),
        });
        final meta = (r.data as Map)['meta'] as Map?;
        return (interview: _one(r), emailSent: meta?['emailSent'] as bool?);
      });

  Future<Interview> cancelInterview(String id, {String? reason}) =>
      _guard(() async => _one(await _dio.post('$_base/$id/cancel', data: {
            if (reason != null && reason.isNotEmpty) 'reason': reason,
            'tzOffsetMinutes': localOffsetMinutes(),
          })));

  /// Only completed / no_show are accepted by the backend.
  Future<Interview> closeOut(String id, InterviewStatus status) =>
      _guard(() async => _one(
          await _dio.patch('$_base/$id/status', data: {'status': status.api})));

  // ----- candidate (for the candidate-facing mobile screens) ---------------

  // ----- live video (both sides) -------------------------------------------

  /// Fetch a fresh LiveKit token each time you join; never cache it.
  /// 409 = outside the join window / interview no longer active.
  Future<JoinInfo> joinToken(String interviewId) => _guard(() async {
        final r = await _dio.post('$_base/$interviewId/join-token');
        return JoinInfo.fromJson(Map<String, dynamic>.from(_data(r) as Map));
      });

  Future<List<Interview>> myInterviews() =>
      _guard(() async => _many(await _dio.get('$_base/me')));

  Future<Interview> confirm(String id) =>
      _guard(() async => _one(await _dio.post('$_base/$id/confirm')));
}

final interviewRepositoryProvider = Provider<InterviewRepository>(
    (ref) => InterviewRepository(ref.watch(dioProvider)));
