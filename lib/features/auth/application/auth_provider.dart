import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/api_loading_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/session_expired_event.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/models/user_model.dart';

// --- Shared singletons, built once and reused across every feature's repository ---

final secureStorageProvider = Provider((ref) => SecureStorageService());

final dioClientProvider = Provider((ref) {
  final client = DioClient(ref.watch(secureStorageProvider));
  client.dio.interceptors.add(LoadingInterceptor(ref));
  return client;
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
      ref.watch(dioProvider), ref.watch(secureStorageProvider));
});

// --- Auth state ---

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  /// Keeps the signed-out workspace visible behind the success modal until
  /// the user chooses where to go next.
  final bool hasJustLoggedOut;

  const AuthState(
      {this.user,
      this.isLoading = false,
      this.error,
      this.hasJustLoggedOut = false});

  bool get isAuthenticated => user != null && !hasJustLoggedOut;

  AuthState copyWith(
      {UserModel? user,
      bool? isLoading,
      String? error,
      bool? hasJustLoggedOut}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasJustLoggedOut: hasJustLoggedOut ?? this.hasJustLoggedOut,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState()) {
    _sessionExpiredSubscription =
        SessionExpiredEvent.instance.stream.listen((_) {
      // Clearing the user causes GoRouter's auth refresh to redirect to login.
      state = const AuthState();
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _sessionExpiredSubscription;

  @override
  void dispose() {
    _sessionExpiredSubscription.cancel();
    super.dispose();
  }

  Future<void> signUp(
      {required String firstName,
      required String lastName,
      required String email,
      required String password,
      required UserRole role}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final registeredUser = await _repository.signUp(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          role: role);
      state = AuthState(user: registeredUser);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(user: state.user, hasJustLoggedOut: true);
  }

  /// Refreshes the cached user after a Settings save (account fields,
  /// photo) — the token/session is untouched, so this is just a state
  /// update, not a re-login.
  void setUser(UserModel user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
