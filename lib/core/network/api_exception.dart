import 'package:dio/dio.dart';

/// Normalizes your backend's `{ status: 'error', message: '...' }` shape
/// (and Zod validation error shapes) into something screens can display directly.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioError(DioException error) {
    final message = _messageFrom(error.response?.data);
    return ApiException(
      message ?? _fallbackMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  static String? _messageFrom(dynamic body) {
    if (body is! Map) return null;
    final candidates = [
      body['message'],
      body['error'],
      body['errors'],
      body['issues'],
      if (body['data'] is Map) ...[
        (body['data'] as Map)['message'],
        (body['data'] as Map)['error'],
        (body['data'] as Map)['errors'],
        (body['data'] as Map)['issues'],
      ],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is List) {
        final messages =
            candidate.map(_nestedMessage).whereType<String>().toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }
      final nested = _nestedMessage(candidate);
      if (nested != null) return nested;
    }
    return null;
  }

  static String? _nestedMessage(dynamic value) {
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is Map) {
      return _nestedMessage(
          value['message'] ?? value['detail'] ?? value['msg']);
    }
    return null;
  }

  static String _fallbackMessage(DioException error) => switch (error.type) {
        DioExceptionType.connectionError =>
          'Could not connect to the server. Check your internet connection and try again.',
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Check your connection and try again.',
        DioExceptionType.cancel =>
          'The request was cancelled. Please try again.',
        DioExceptionType.badResponse =>
          'The server could not complete the request. Please try again.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => message;
}
