import 'package:dio/dio.dart';
import 'package:talentbridge/core/utils/app_config.dart';
import '../storage/secure_storage_service.dart';

///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.yourapp.com/api
final String kApiBaseUrl = ApiConfig.baseUrl;

/// Attaches the access token to every request, and on a 401, tries exactly
/// once to refresh via /auth/refresh before giving up and clearing tokens
/// (which the router's redirect logic picks up to bounce back to /login).
class DioClient {
  DioClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
    ));
    _refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
    _dio.interceptors.add(_authInterceptor());
  }

  late final Dio _dio;
  late final Dio _refreshDio;

  final SecureStorageService _storage;
  bool _isRefreshing = false;

  Dio get dio => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;

        if (!isUnauthorized || alreadyRetried || _isRefreshing) {
          return handler.next(error);
        }

        _isRefreshing = true;
        try {
          final refreshToken = await _storage.getRefreshToken();
          if (refreshToken == null) {
            await _storage.clearTokens();
            return handler.next(error);
          }

          // TODO: match to your actual refresh endpoint/response field names
          final response = await _refreshDio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final newAccessToken = response.data['accessToken'] as String;
          final newRefreshToken = response.data['refreshToken'] as String;
          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          final retryOptions = error.requestOptions;
          retryOptions.extra['retried'] = true;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          await _storage.clearTokens();
          return handler.next(error);
        } finally {
          _isRefreshing = false;
        }
      },
    );
  }
}
