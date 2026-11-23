import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/network/dio_client.dart';
import '../../application/auth_provider.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.email,
    this.token,
    this.returnTo,
    this.onboarding = false,
    this.verified = false,
  });

  final String? email;
  final String? token;
  final String? returnTo;
  final bool onboarding;
  final bool verified;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final String _email;
  bool _verifying = false;
  bool _verified = false;
  bool _resending = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _email = widget.email?.trim().isNotEmpty == true
        ? widget.email!.trim()
        : ref.read(authProvider).verificationEmail ?? '';
    _verified = widget.verified;
    if (widget.token?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confirmToken());
    }
  }

  Future<void> _confirmToken() async {
    final token = widget.token;
    if (token == null || token.isEmpty || _verifying || _verified) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final verifiedEmail =
          await ref.read(authProvider.notifier).verifyEmailToken(token);
      if (!mounted) return;
      setState(() {
        _verified = true;
        _verifying = false;
      });
      final email = verifiedEmail.isNotEmpty ? verifiedEmail : _email;
      // Remove the one-time bearer token from the address bar after use.
      context.go(_loginLocation(email));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _resend() async {
    if (_email.isEmpty || _resending || _resendSeconds > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await requestEmailVerification(email: _email, dio: ref.read(dioProvider));
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If this account needs verification, a fresh link will be sent shortly.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'We could not request a new link. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String _loginLocation(String email) => Uri(
        path: '/login',
        queryParameters: {
          if (email.isNotEmpty) 'email': email,
          if (widget.returnTo != null) 'returnTo': widget.returnTo!,
          if (widget.onboarding || widget.returnTo != null) 'onboarding': 'true',
          if (_verified || widget.verified) 'verified': 'true',
        },
      ).toString();

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isConfirmed = _verified || widget.verified;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        isConfirmed ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                        size: 58,
                        color: isConfirmed ? Colors.green : colors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isConfirmed ? 'Email verified' : 'Verify your email',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isConfirmed
                            ? 'Your email is confirmed. Sign in to continue to your profile setup.'
                            : 'We sent a one-time verification link. Confirm your email before signing in or creating your profile.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_email.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Email', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        SelectableText(_email, textAlign: TextAlign.center),
                      ],
                      if (_verifying) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 8),
                        const Text('Confirming your email…', textAlign: TextAlign.center),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (isConfirmed)
                        FilledButton(
                          onPressed: () => context.go(_loginLocation(_email)),
                          child: const Text('Continue to sign in'),
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _resendSeconds > 0 || _resending || _email.isEmpty
                              ? null
                              : _resend,
                          icon: _resending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _resendSeconds > 0
                                ? 'Resend link in ${_resendSeconds}s'
                                : 'Resend verification link',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(_loginLocation(_email)),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'The link expires after one hour and can only be used once.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
