import 'package:dio/dio.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'models/user_model.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  /// Registers the account, then immediately logs in with the same
  /// credentials to obtain and store real tokens.
  ///
  /// There's no email-verification step in the flow yet, so this treats
  /// "registered" and "authenticated" as the same moment. Once email
  /// verification exists, this needs to change — likely: don't
  /// auto-login here, and instead route the user to a "check your
  /// email" screen, then let them log in normally once verified.
  ///
  /// ASSUMPTION: `role.name.toUpperCase()` matches the backend's Role
  /// enum values (CANDIDATE / RECRUITER / ADMIN). Confirm against
  /// UserRole's actual definition and adjust if it doesn't serialize
  /// that way.
  Future<UserModel> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      // POST /auth/register returns only { userId } — no tokens, so
      // there's nothing to store from this call itself.
      await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role.name,
      });

      return await login(email: email, password: password);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final loginData = _sessionData(response.data);

      final accessToken = loginData['accessToken'] as String;
      final refreshToken = loginData['refreshToken'] as String;

      await _storage.saveTokens(
          accessToken: accessToken, refreshToken: refreshToken);

      final me = await _dio.get('/auth/me');
      final profileData = _sessionData(me.data);
      // /auth/me is the source of profile fields; retain session entitlements
      // from login when that endpoint returns only account details.
      final userData = <String, dynamic>{...loginData, ...profileData};
      return UserModel.fromJson(userData);
    } on DioException catch (e) {
      // A token may have been saved before the follow-up /auth/me request
      // failed. Do not leave a half-created session behind after a failed
      // sign-in attempt.
      try {
        await _storage.clearTokens();
      } catch (_) {}
      throw ApiException.fromDioError(e);
    }
  }

  /// The API envelope is `{ status, data: { ... } }`; some older endpoints
  /// return the inner object directly. A nested `user` object is also
  /// accepted while retaining sibling entitlement fields.
  Map<String, dynamic> _sessionData(dynamic responseData) {
    if (responseData is! Map) return const {};
    final root = Map<String, dynamic>.from(responseData);
    final data = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;
    if (data['user'] is Map) {
      return <String, dynamic>{
        ...data,
        ...Map<String, dynamic>.from(data['user'] as Map),
      };
    }
    return data;
  }

  Future<void> logout() async {
    await _storage.clearTokens();
  }

  Future<bool> hasStoredSession() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }

  /// Kicks off the reset email. Backend always returns 200 regardless of
  /// whether the email is registered (so it doesn't leak account existence)
  /// — don't branch UI behavior on success/failure here beyond network errors.
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _dio.post('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Consumes the token from the reset-link email. On success the backend
  /// invalidates the user's refresh token (logs out all devices), so the
  /// caller should route back to login rather than treating this as an
  /// authenticated session.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/reset-password', data: {
        'token': token,
        'newPassword': newPassword,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
