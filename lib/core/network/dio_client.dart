import 'package:dio/dio.dart';
import 'package:talentbridge/core/utils/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'session_expired_event.dart';

///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.yourapp.com/api
final String kApiBaseUrl = ApiConfig.baseUrl;

/// Adds the access token to requests, refreshes it once after an auth failure,
/// and publishes a terminal session-expired event if refresh cannot recover.
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
  Future<String?>? _refreshInFlight;

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
        final isUnauthorized = _isAuthFailure(error);
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        final isAuthRequest = _isAuthEndpoint(error.requestOptions.path);

        if (!isUnauthorized || isAuthRequest) {
          return handler.next(error);
        }

        if (alreadyRetried) {
          await _expireSession();
          return handler.next(error);
        }

        try {
          final accessToken =
              await (_refreshInFlight ??= _refreshAccessToken());
          if (accessToken == null) {
            await _expireSession();
            return handler.next(error);
          }

          final retryOptions = error.requestOptions;
          retryOptions.extra['retried'] = true;
          retryOptions.headers['Authorization'] = 'Bearer $accessToken';

          final retryResponse = await _dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        } catch (_) {
          await _expireSession();
          return handler.next(error);
        } finally {
          _refreshInFlight = null;
        }
      },
    );
  }

  bool _isAuthFailure(DioException error) {
    if (error.response?.statusCode == 401) return true;
    final response = error.response?.data;
    final message = response is Map
        ? '${response['message'] ?? response['error'] ?? response['detail'] ?? ''}'
        : '$response';
    final normalized = message.toLowerCase();
    return normalized.contains('authorization header') ||
        normalized.contains('jwt expired') ||
        normalized.contains('token expired') ||
        normalized.contains('invalid token');
  }

  bool _isAuthEndpoint(String path) {
    final normalized = path.toLowerCase();
    return normalized.endsWith('/auth/login') ||
        normalized.endsWith('/auth/register') ||
        normalized.endsWith('/auth/refresh') ||
        normalized.endsWith('/auth/refresh-token');
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _refreshDio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final payload = _responsePayload(response.data);
      final accessToken = payload['accessToken'] as String?;
      final newRefreshToken = payload['refreshToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) return null;

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: (newRefreshToken == null || newRefreshToken.isEmpty)
            ? refreshToken
            : newRefreshToken,
      );
      return accessToken;
    } on DioException catch (error) {
      // Some deployments expose the shorter route; fall back only when the
      // configured route is absent, not when the refresh credential is bad.
      if (error.response?.statusCode != 404 &&
          error.response?.statusCode != 405) {
        return null;
      }
      try {
        final response = await _refreshDio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        final payload = _responsePayload(response.data);
        final accessToken = payload['accessToken'] as String?;
        final newRefreshToken = payload['refreshToken'] as String?;
        if (accessToken == null || accessToken.isEmpty) return null;
        await _storage.saveTokens(
          accessToken: accessToken,
          refreshToken: (newRefreshToken == null || newRefreshToken.isEmpty)
              ? refreshToken
              : newRefreshToken,
        );
        return accessToken;
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _responsePayload(dynamic body) {
    if (body is! Map) return const {};
    var payload = Map<String, dynamic>.from(body);
    if (payload['data'] is Map) {
      payload = Map<String, dynamic>.from(payload['data'] as Map);
    }
    if (payload['user'] is Map) {
      payload = Map<String, dynamic>.from(payload['user'] as Map);
    }
    return payload;
  }

  Future<void> _expireSession() async {
    await _storage.clearTokens();
    SessionExpiredEvent.instance.notify();
  }
}
