import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_provider.dart';

/// Lands here from the link in the reset-password email, e.g. a route like
///   GoRoute(
///     path: '/reset-password',
///     builder: (context, state) =>
///         ResetPasswordScreen(token: state.uri.queryParameters['token'] ?? ''),
///   ),
/// ASSUMPTION: the email link encodes the token as a query param
/// (?token=...). Adjust the route + this constructor if your deep link
/// shape differs (e.g. a path segment instead).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  bool _done = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.token.isEmpty) {
      setState(() => _errorText =
          'This reset link is missing or malformed. Please request a new one.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: widget.token,
            newPassword: _passwordController.text,
          );

      if (!mounted) return;
      setState(() => _done = true);
      AppToast.success(context, 'Password updated successfully.');
    } catch (e) {
      // Token invalid/expired is the main failure mode here (backend
      // returns 401 for that) — surface a message pointing back to
      // requesting a fresh link rather than a generic retry.
      if (mounted) {
        setState(() => _errorText =
            'This link is invalid or has expired. Please request a new reset link.');
        AppToast.error(context,
            'This link is invalid or expired. Request a new reset link.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToLogin() => context.go('/login');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BrandColors.border),
                    ),
                    child: _done
                        ? _DoneState(onContinue: _goToLogin)
                        : _buildForm(),
                  ),
                  const SizedBox(height: 24),
                  const BrandFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandHeader(
            title: 'Set a new password',
            subtitle: 'Choose a new password for your account.',
            titleFontSize: 20,
          ),
          const SizedBox(height: 24),
          const Text('NEW PASSWORD', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: authInputDecoration(
              hint: '••••••••',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: BrandColors.navy,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 16),
          const Text('CONFIRM PASSWORD', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: authInputDecoration(
              hint: '••••••••',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: BrandColors.navy,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            style: const TextStyle(color: BrandColors.navy),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Reset Password',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DoneState extends StatelessWidget {
  const _DoneState({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrandHeader(
          title: 'Password reset',
          subtitle: 'Your password has been changed successfully.',
          titleFontSize: 20,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandColors.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            children: [
              Icon(Icons.check_circle_outline,
                  color: BrandColors.navy, size: 28),
              SizedBox(height: 10),
              Text(
                "You've been logged out of all devices for security. Please log in again with your new password.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: BrandColors.navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Back to Login',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
