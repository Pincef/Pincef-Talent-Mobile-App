import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/api_loading_interceptor.dart';
import 'package:talentbridge/core/network/api_exception.dart';
import 'package:talentbridge/core/network/dio_client.dart';
import 'package:talentbridge/core/network/session_expired_event.dart';
import 'package:talentbridge/core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

final dioClientProvider = Provider((ref) {
  final client = DioClient(ref.watch(secureStorageProvider));
  client.dio.interceptors.add(LoadingInterceptor(ref));
  return client;
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final authRepositoryProvider = Provider((ref) => AuthRepository(
      ref.watch(dioProvider),
      ref.watch(secureStorageProvider),
    ));

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isRestoringSession;
  final bool sessionRestoreFailed;
  final bool isVerifyingEmail;
  final String? verificationEmail;
  final String? error;
  final bool hasJustLoggedOut;
  final bool isOnboarding;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isRestoringSession = false,
    this.sessionRestoreFailed = false,
    this.isVerifyingEmail = false,
    this.verificationEmail,
    this.error,
    this.hasJustLoggedOut = false,
    this.isOnboarding = false,
  });

  bool get isAuthenticated => user != null && !hasJustLoggedOut;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository)
      : super(const AuthState(isRestoringSession: true)) {
    _sessionExpiredSubscription = SessionExpiredEvent.instance.stream.listen((_) {
      state = const AuthState();
    });
    unawaited(_restoreStoredSession());
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  @override
  void dispose() {
    _sessionExpiredSubscription.cancel();
    super.dispose();
  }

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required UserRole role,
    String country = 'NG',
    String? returnTo,
  }) async {
    state = AuthState(
      isLoading: true,
      isVerifyingEmail: true,
      verificationEmail: email,
      isOnboarding: true,
    );
    try {
      await _repository.signUp(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        role: role,
        country: country,
        returnTo: returnTo,
      );
      state = AuthState(
        isVerifyingEmail: true,
        verificationEmail: email,
        isOnboarding: true,
      );
    } catch (error) {
      state = AuthState(error: error.toString());
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = AuthState(isLoading: true);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user);
    } catch (error) {
      if (error is ApiException &&
          error.code == 'EMAIL_VERIFICATION_REQUIRED') {
        state = AuthState(
          isVerifyingEmail: true,
          verificationEmail: email,
          isOnboarding: true,
          error: error.message,
        );
      } else {
        state = AuthState(error: error.toString());
      }
      rethrow;
    }
  }

  Future<UserModel> completeGoogleOAuth(String handoffCode) async {
    state = const AuthState(isLoading: true);
    try {
      final user = await _repository.completeGoogleOAuth(handoffCode);
      state = AuthState(user: user);
      return user;
    } catch (error) {
      state = AuthState(error: error.toString());
      rethrow;
    }
  }

  Future<String> verifyEmailToken(String token) async {
    final email = await _repository.confirmEmailVerification(token: token);
    state = const AuthState();
    return email;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(hasJustLoggedOut: true);
  }

  void setUser(UserModel user) => state = AuthState(user: user);

  Future<void> retrySessionRestore() async {
    state = const AuthState(isRestoringSession: true);
    await _restoreStoredSession();
  }

  Future<void> clearFailedSession() async {
    await _repository.logout();
    state = const AuthState();
  }

  Future<void> _restoreStoredSession() async {
    try {
      if (!await _repository.hasStoredSession()) {
        state = const AuthState();
        return;
      }
      final user = await _repository.restoreSession();
      if (!user.isEmailVerified) {
        state = AuthState(
          user: user,
          isVerifyingEmail: true,
          verificationEmail: user.email,
          isOnboarding: true,
        );
      } else {
        state = AuthState(user: user);
      }
    } catch (error) {
      if (error is ApiException &&
          error.code == 'EMAIL_VERIFICATION_REQUIRED') {
        state = AuthState(
          isVerifyingEmail: true,
          verificationEmail: error.email,
          isOnboarding: true,
          error: error.message,
        );
        return;
      }
      if (await _repository.hasStoredSession()) {
        state = const AuthState(
          sessionRestoreFailed: true,
          error: 'Could not reconnect to your account. Check your connection and retry.',
        );
      } else {
        state = const AuthState();
      }
    }
  }

  Future<void> refreshSession() async {
    final user = await _repository.refreshSession();
    state = AuthState(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

Future<void> requestEmailVerification({
  required String email,
  required Dio dio,
}) async {
  await dio.post('/auth/verify-email', data: {'email': email});
}

Future<void> completeEmailVerification({
  required String token,
  required AuthNotifier notifier,
}) async {
  await notifier.verifyEmailToken(token);
}
