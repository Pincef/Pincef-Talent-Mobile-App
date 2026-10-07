import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._dio);
  final SecureStorageService _storage;
  final Dio _dio; // plain Dio, no interceptors, used only for refresh calls

  bool _isRefreshing = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isRetry = err.requestOptions.extra['retried'] == true;

    if (!isUnauthorized || isRetry) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      handler.next(err); // avoid stampede; simplest safe fallback
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        handler.next(err);
        return;
      }

      final response = await _dio.post('/auth/refresh-token', data: {
        'refreshToken': refreshToken,
      });

      final responseData = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final refreshData = responseData['data'] is Map
          ? Map<String, dynamic>.from(responseData['data'] as Map)
          : responseData;
      final newAccessToken = refreshData['accessToken'] as String;
      final newRefreshToken = refreshData['refreshToken'] as String?;

      await _storage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      retryOptions.extra['retried'] = true;

      final cloneDio = Dio(BaseOptions(baseUrl: retryOptions.baseUrl));
      final retryResponse = await cloneDio.fetch(retryOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await _storage.clearTokens();
      handler.next(err); // let the app route to /login on this failure
    } finally {
      _isRefreshing = false;
    }
  }
}
