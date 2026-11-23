import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/dio_client.dart';

import '../auth_provider.dart';

/// --- Verification screen shown after sign-up (or after session restore
///     if the user's email is not yet verified).
///
/// The screen:
/// * Pre-fills the user's email (cannot be edited).
/// * Shows a timer counting down to a "Resend" action.
/// * Provides "I've verified my email" (navigates forward) and
///   "Skip for now" (proceeds to onboarding unverified).
/// * Communicates with the backend via the shared Dio client.

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final dio = ref.watch(dioProvider);

    // If the user was signed up just now, the email is already in state;
    // otherwise fall back to an empty string (should not happen in practice).
    final email = auth.user?.email ?? '';

    // Resend timer state
    final resendState = ref.watch(_verifyEmailResendProvider(email));
    final canResend = resendState.isResendAvailable;
    final resendCountdown = resendState.countdown;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Icon(
                Icons.email_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                'A verification link has been sent to your email address. '
                'Please check your inbox and click the link to continue.',
                style: TextStyle(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Email display (pre-filled, read-only)
              Text(
                'Email: $email',
                style: const TextStyle(fontFamily: 'Manrope'),
              ),
              const SizedBox(height: 24),

              // Resend timer
              if (canResend)
                Text(
                  'You can request a new link in $resendCountdown s',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                const Text(
                  'If you did not receive the email, check your spam folder.',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),

              // Resend button (visible only when off cooldown)
              if (!resendState.isLoading && canResend)
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(_verifyEmailResendProvider(email).notifier).state =
                          const _ResendState.loading(),
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Resend verification email'),
                ),
              const SizedBox(height: 32),

              // Action: User has clicked the link in email
              ElevatedButton(
                onPressed: () {
                  // User says they've verified; navigate forward.
                  // The actual verification status is checked by the router.
                  Navigator.of(context).pop();
                },
                child: const Text('I've verified my email'),
              ),
              const SizedBox(height: 8),
              // Action: Skip verification and go to onboarding
              OutlinedButton(
                onPressed: () {
                  // Allow bypass; the backend will auto-verify after a grace period.
                  Navigator.of(context).pop();
                },
                child: const Text('Skip for now'),
              ),
              const SizedBox(height: 48),

              // Footer note
              const Text(
                "Can't find the email? Check your spam folder.",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
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

/// Small notifier used by the verification screen to manage the resend timer.
/// Kept separate so the timer logic isn't embedded in the widget build method.
class _ResendState {
  final bool isLoading;
  final bool isResendAvailable;
  final int countdown;

  _ResendState._({
    required this.isLoading,
    required this.isResendAvailable,
    required this.countdown,
  });

  factory _ResendState.loading() => const _ResendState(
        isLoading: true,
        isResendAvailable: true,
        countdown: 30,
      );

  factory _ResendState.initial(String email, Dio dio) {
    // Start a 30-second countdown; the first resend is immediate (countdown=30),
    // then decrements each second via the listener below.
    return _ResendState._(
      isLoading: false,
      isResendAvailable: true,
      countdown: 30,
    );
  }
}

// Persist the resend state in provider so it survives setState pop/push
// and so the countdown logic can run independently of the widget's own state.
final _verifyEmailResendProvider =
    StateNotifierProvider<_ResendNotifier, _ResendState>((ref, email) {
  final dio = ref.watch(dioProvider);
  return _ResendNotifier(dio, email);
});

class _ResendNotifier : StateNotifier<_ResendState> {
  _ResendNotifier(Dio dio, String email)
      : super(_ResendState.initial(email, dio)) {
    // Start the 1-second tick timer.
    _tick = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  late final Timer _tick;

  _ResendState _onTick(_) {
    final newCount = state.countdown - 1;
    if (newCount < 0) {
      _tick.cancel();
      // Persist that resends are now available at 30s again.
      state = _ResendState._(
        isLoading: false,
        isResendAvailable: true,
        countdown: 30,
      );
      return;
    }
    state = _ResendState._(
      isLoading: false,
      isResendAvailable: false,
      countdown: newCount,
    );
    return null;
  }

  /// Call the backend to send a fresh verification email.
  Future<void> sendResend() async {
    state = state.copyWith(isLoading: true);
    try {
      // The backend endpoint mirrors the one used during sign-up.
      await dio.post('/auth/verify-email', data: {'email': state.email});
      // After a successful resend, reset the timer to 30s and mark as available.
      state = _ResendState._(
        isLoading: false,
        isResendAvailable: true,
        countdown: 30,
      );
    } on DioException catch (_) {
      // On failure keep the timer where it is so the user can retry.
      rethrow;
    }
  }

  // Expose the email so the widget can display it without re-reading auth state.
  String get email => state.email;
}

// Provide the email string so widgets don't have to read auth state twice.
extension _VerifyEmailResendStateX on _ResendState {
  String get email => _ResendNotifier.email;
}