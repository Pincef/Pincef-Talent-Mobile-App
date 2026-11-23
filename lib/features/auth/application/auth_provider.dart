import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:talentbridge/core/network/api_loading_interceptor.dart';
import 'package:talentbridge/core/network/dio_client.dart';
import 'package:talentbridge/core/network/session_expired_event.dart';
import 'package:talentbridge/core/storage/secure_storage_service.dart';
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
  final bool isRestoringSession;
  final bool sessionRestoreFailed;
  final bool isVerifyingEmail;
  final String? error;
  final bool hasJustLoggedOut;

  /// Keeps the signed-out workspace visible behind the success modal until
  /// the user chooses where to go next.
  final bool isOnboarding;

  const AuthState(
      {this.user,
      this.isLoading = false,
      this.isRestoringSession = false,
      this.sessionRestoreFailed = false,
      this.isVerifyingEmail = false,
      this.error,
      this.hasJustLoggedOut = false,
      this.isOnboarding = false});

  bool get isAuthenticated => user != null && !hasJustLoggedOut;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isRestoringSession,
    bool? sessionRestoreFailed,
    bool? isVerifyingEmail,
    String? error,
    bool? hasJustLoggedOut,
    bool? isOnboarding,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      sessionRestoreFailed: sessionRestoreFailed ?? this.sessionRestoreFailed,
      isVerifyingEmail: isVerifyingEmail ?? this.isVerifyingEmail,
      error: error,
      hasJustLoggedOut: hasJustLoggedOut ?? this.hasJustLoggedOut,
      isOnboarding: isOnboarding ?? this.isOnboarding,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository)
      : super(const AuthState(isRestoringSession: true)) {
    _sessionExpiredSubscription =
        SessionExpiredEvent.instance.stream.listen((_) {
      // Clearing the user causes GoRouter's auth refresh to redirect to login.
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

  /// [signUp] no longer auto-logs in. Instead it routes the user to a
  /// verification screen. The caller (GoRouter) should display that screen
  /// when [isVerifyingEmail] is true.
  Future<void> signUp(
      {
      required String firstName,
      required String lastName,
      required String email,
      required String password,
      required UserRole role,
      String country = 'NG',
      String? returnTo}) async {
    state = state.copyWith(isLoading: true, error: null, isVerifyingEmail: true);

    try {
      // POST /auth/register returns only { userId } — no tokens, so
      // there's nothing to store from this call itself.
      await _dio.post('/auth/register', data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'role': role.name,
        'country': country,
        if (returnTo != null) 'returnTo': returnTo,
      });

      // Do NOT auto-login. The user must verify their email first.
      // We keep the session unverified so the onboarding flow can reset.
      state = AuthState(
        isVerifyingEmail: true,
        isOnboarding: true,
      );
    } on DioException catch (e) {
      state = AuthState(
        isLoading: false,
        isVerifyingEmail: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user, isVerifyingEmail: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString(), isVerifyingEmail: false);
      rethrow;
    }
  }

  Future<void> completeGoogleOAuth(String handoffCode) async {
    state = state.copyWith(isLoading: true, error: null, isVerifyingEmail: true);

    try {
      final user = await _repository.completeGoogleOAuth(handoffCode);
      // Google OAuth users are considered verified immediately.
      state = AuthState(user: user, isVerifyingEmail: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString(), isVerifyingEmail: true);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(user: state.user, hasJustLoggedOut: true);
  }

  /// Refreshes the cached user after a Settings save (account fields, photo)
  /// — the token/session is untouched, so this is just a state update, not
  /// a re-login.
  void setUser(UserModel user) {
    state = state.copyWith(user: user, isVerifyingEmail: false);
  }

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
      // If the restored user has not yet verified email, stay on the
      // verification screen rather than auto-redircting to dashboard.
      if (user.isEmailVerified == false) {
        state = AuthState(user: user, isVerifyingEmail: true, isOnboarding: true);
      } else {
        state = AuthState(user: user);
      }
    } catch (_) {
      // Keep stored credentials through temporary network failures. The app
      // shows a retry screen instead of sending the user to login or dropping
      // a still-valid refresh token.
      if (await _repository.hasStoredSession()) {
        state = AuthState(
          sessionRestoreFailed: true,
          isVerifyingEmail: true,
          error:
              'Could not reconnect to your account. Check your connection and retry.',
        );
      } else {
        state = const AuthState();
      }
    }
  }

  Future<void> refreshSession() async {
    final user = await _repository.refreshSession();
    state = state.copyWith(user: user, isVerifyingEmail: false);
  }
}

// When the user's email is verified by the backend, we need a way to signal
// that from the API. For now the back-end returns `isEmailVerified` in the
// user model. The AuthState tracks this and the GoRouter watches it.

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Verification helpers — called from the UI or GoRouter.
// ---------------------------------------------------------------------------

/// Request a fresh verification email. The backend always returns 200.
Future<void> requestEmailVerification(
    {required String email, required Dio dio}) async {
  try {
    await dio.post('/auth/verify-email', data: {'email': email});
  } on DioException catch (e) {
    // Don't branch UI on success/failure (avoids leaking account existence).
    // Only re-throw on network errors.
    rethrow;
  }
}

/// Mark the current user's email as verified on the backend and update the
/// local state so GoRouter can redirect to the onboarding/dashboard flow.
Future<void> completeEmailVerification(
    {required String token, required AuthNotifier notifier}) async {
  try {
    await notifier._dio.post('/auth/verify-email/confirm', data: {'token': token});
    // Refresh the user so isEmailVerified reflects the new state.
    final user = await notifier._repository.refreshSession();
    notifier.setUser(user);
  } on DioException catch (e) {
    // Keep the user on the verification screen; they can retry.
    rethrow;
  }
}

// ---------------------------------------------------------------------------
// GoRouter transition guards — these watch the auth state and decide where
// the user goes. They live in GoRouter's `redirect` or `pathMatchingPrefix`.
// ---------------------------------------------------------------------------

/// New users (no stored session) land on the welcome screen.
/// Returning users whose email is unverified go to the verification screen.
/// Verified users go to their role-specific onboarding/dashboard.
String? authRedirect(BuildContext context, GoRouteState state) {
  final auth = ref.watch(authProvider);
  // If we're inside the verification flow, stay on the verification screen.
  if (auth.isVerifyingEmail) return '/verify-email';

  // No stored session → welcome.
  if (!auth.isAuthenticated) return '/welcome';

  // Verified user → dashboard/onboarding (role-dependent below).
  // The final destination is decided by the role-specific router.
  return null;
}

// ---------------------------------------------------------------------------
// Screens
// ---------------------------------------------------------------------------

/// Verification screen shown after sign-up (or after restore if unverified).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailController;
  late final FocusNode _emailFocus;
  bool _resending = false;
  String? _resendError;
  Timer? _resendTimer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    // Read the email from the auth state if it was set during sign-up,
    // otherwise fall back to stored session data.
    final auth = ref.read(authProvider);
    final email = auth.user?.email ?? '';
    _emailController = TextEditingController(text: email);
    _emailFocus = FocusNode();
    // Start the resend timer if the user already has a pending verification.
    _startResendTimer();
    // Hide the keyboard so the UI feels light on load.
    WidgetsBinding.instance.focusScope?.unfocus();
  }

  void _startResendTimer() {
    const oneSec = Duration(seconds: 1);
    _resendTimer = Timer.periodic(oneSec, (_) {
      if (!mounted) return;
      setState(() {
        _resendSeconds = _resendSeconds - 1;
        if (_resendSeconds <= 0) {
          _resendTimer?.cancel();
          _resendTimer = null;
          _resendSeconds = 30;
        }
      });
    });
  }

  void _resendVerification() async {
    setState(() {
      _resending = true;
      _resendError = null;
    });
    final dio = ref.read(dioProvider);
    try {
      await requestEmailVerification(
          email: _emailController.text, dio: dio);
      // Reset the timer so the user sees 30s from the new send.
      _resendSeconds = 30;
    } on DioException catch (e) {
      setState(() => _resendError = e.toString());
    } finally {
      setState(() => _resending = false);
    }
  }

  void _onVerifyPressed() {
    // When the user taps "Verify", we signal the backend and then
    // navigate based on the result. The actual verification is handled
    // by the link in the email; this screen simply guides the user.
    // If the backend has a one-tap confirm endpoint we could call it here,
    // but the standard flow is: check email → click link → redirect.
    // For now we just navigate forward and let the router decide.
    Navigator.of(context).pop();
  }

  void _onSkipPressed() {
    // Allow the user to bypass verification and go straight to onboarding.
    // The backend will mark the user as verified after N days or on next
    // login; for now we just proceed.
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar / icon
              Icon(
                Icons.email_outlined,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Verify Your Email',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'A verification link has been sent to your email address. '
                'Please check your inbox and click the link to continue.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email field (pre-filled)
              TextField(
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: false, // email is fixed from sign-up
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: _emailController.text,
                  border: OutlineInputBorder(),
                  suffixIcon: _resending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                textCapitalization: TextCapitalization.none,
              ),
              const SizedBox(height: 24),

              // Resend link (shown only after a short cooldown)
              if (_resendSeconds < 30)
                Text(
                  'You can request a new link in $_resendSeconds s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (_resendSeconds == 30 && !_resending)
                TextButton(
                  onPressed: _resendVerification,
                  child: const Text('Resend verification email'),
                ),
              const SizedBox(height: 32),

              // Action buttons
              ElevatedButton.icon(
                onPressed: _onVerifyPressed,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('I've verified my email'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _onSkipPressed,
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: 48),

              // Footer note
              Text(
                "Can't find the email? Check your spam folder.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding screen shown after verification. The destination depends on
/// the user's role. This is a placeholder that GoRouter replaces with the
/// appropriate role-specific flow.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    // Show a simple welcome with role-based next step.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome, ${user?.fullName ?? ''}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'You're all set up. Begin exploring the app below.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate based on role — GoRouter handles this.
                // The actual role-specific screens are defined in app_router.dart.
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router transitions (minimal — full GoRouter config lives in app_router.dart)
// ---------------------------------------------------------------------------

// This redirect runs on every app start and route change. It decides where
// the user goes based on auth state and email verification status.
String? authRouteRedirect(BuildContext context, GoRouteState state) {
  final auth = ref.watch(authProvider);

  // 1. If the user is currently in the verification flow, show the verification screen.
  if (auth.isVerifyingEmail) {
    return '/verify-email';
  }

  // 2. No stored session → welcome screen (new visitors).
  if (!auth.isAuthenticated) {
    return '/welcome';
  }

  // 3. Verified user → let the role-specific router decide.
  //    The GoRouter named routes (/, /dashboard, /admin, etc.) already have
  //    their own role-based guards, so we just pass through.
  return null;
}

// ---------------------------------------------------------------------------
// Router definition stub — integrate these routes into your GoRouter.
// ---------------------------------------------------------------------------

// Add these routes to your GoRouter(routes: [...]) collection:
//   GoRoute(path: '/verify-email', name: 'verifyEmail', builder: (_) => const VerifyEmailScreen()),
//   GoRoute(path: '/onboarding', name: 'onboarding', builder: (_) => const OnboardingScreen()),
//   GoRoute(path: '/welcome', name: 'welcome', builder: (_) => const WelcomeScreen()),
//   GoRoute(path: '/', name: 'dashboard', builder: (_) => const DashboardScreen()), // role-dependent