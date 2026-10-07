import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/models/hiring_pipeline_model.dart';

/// The backend DTO (zod, non-strict) currently DROPS everything except
/// `name` and `stages[].type/name`. Flip this to `true` once the backend
/// accepts description / status / stage `required` / stage `config`.
const bool kSendExtendedPipelineFields = false;

class PipelineApiException implements Exception {
  PipelineApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HiringPipelineRepository {
  HiringPipelineRepository(this._dio);
  final Dio _dio;

  // ApiConfig.baseUrl already ends with /api.
  static const _path = '/hiring-pipelines';

  Future<List<HiringPipeline>> list() => _guard(() async {
        final res = await _dio.get<dynamic>(_path);
        final data = (res.data as Map)['data'] as List;
        return data
            .map((e) =>
                HiringPipeline.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  Future<PipelineCapabilities> capabilities() => _guard(() async {
        final res = await _dio.get<dynamic>('$_path/capabilities');
        return PipelineCapabilities.fromJson(
          Map<String, dynamic>.from((res.data as Map)['data'] as Map),
        );
      });

  Future<HiringPipeline> create({
    required String name,
    required List<PipelineStage> stages,
    String? description,
    String? status,
  }) =>
      _guard(() async {
        final res = await _dio.post<dynamic>(_path, data: {
          'name': name,
          'stages': _stages(stages),
          if (kSendExtendedPipelineFields) ...{
            if (description != null) 'description': description,
            if (status != null) 'status': status,
          },
        });
        return _one(res);
      });

  Future<HiringPipeline> update(
    String id, {
    String? name,
    List<PipelineStage>? stages,
    String? description,
    String? status,
  }) =>
      _guard(() async {
        final res = await _dio.patch<dynamic>('$_path/$id', data: {
          if (name != null) 'name': name,
          if (stages != null) 'stages': _stages(stages),
          if (kSendExtendedPipelineFields) ...{
            if (description != null) 'description': description,
            if (status != null) 'status': status,
          },
        });
        return _one(res);
      });

  Future<void> delete(String id) => _guard(() async {
        await _dio.delete<dynamic>('$_path/$id');
      });

  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> _stages(List<PipelineStage> stages) => [
        for (final s in stages)
          s.toRequestJson(extended: kSendExtendedPipelineFields),
      ];

  HiringPipeline _one(Response<dynamic> res) => HiringPipeline.fromJson(
        Map<String, dynamic>.from((res.data as Map)['data'] as Map),
      );

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PipelineApiException {
      rethrow;
    } on DioException catch (e) {
      final data = e.response?.data;
      var message = 'Something went wrong. Please try again.';
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'Network problem. Check your connection and try again.';
      }
      throw PipelineApiException(message, e.response?.statusCode);
    } catch (e, st) {
      debugPrint('HiringPipelineRepository parse error: $e\n$st');
      throw PipelineApiException('Unexpected response from the server.');
    }
  }
}
