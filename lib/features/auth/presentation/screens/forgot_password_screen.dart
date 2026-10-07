import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(
            email: _emailController.text.trim(),
          );

      if (!mounted) return;
      setState(() => _sent = true);
      AppToast.success(
          context, 'If the account exists, a reset email is on its way.');
    } catch (e) {
      // Deliberately generic — the backend gives the same response whether
      // or not the email is registered, so a network/server error is the
      // only case we surface differently here.
      if (mounted) {
        setState(() => _errorText = 'Something went wrong. Please try again.');
        AppToast.error(
            context, 'Could not send the reset email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _backToLogin() {
    // Pushed from login normally, but guard in case this screen was
    // reached some other way (e.g. a direct/deep link) with nothing
    // to pop back to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

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
                    child: _sent
                        ? _SentState(
                            email: _emailController.text.trim(),
                            onBack: _backToLogin)
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
            title: 'Forgot your password?',
            subtitle:
                "Enter your email address and we'll send you a link to reset your password.",
            titleFontSize: 20,
          ),
          const SizedBox(height: 24),
          const Text('EMAIL ADDRESS', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: authInputDecoration(
                hint: 'name@company.com', icon: Icons.mail_outline),
            validator: emailValidator,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Send Reset Link',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: _backToLogin,
              icon: const Icon(Icons.arrow_back,
                  size: 15, color: BrandColors.muted),
              label: const Text('Back to Login',
                  style: TextStyle(fontSize: 13, color: BrandColors.muted)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentState extends StatelessWidget {
  const _SentState({required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BrandHeader(
          title: 'Forgot your password?',
          subtitle:
              "Enter your email address and we'll send you a link to reset your password.",
          titleFontSize: 20,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandColors.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  color: BrandColors.navy, size: 28),
              const SizedBox(height: 10),
              Text(
                email.isEmpty
                    ? 'Check your email for a reset link.'
                    : "We've sent a reset link to $email.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: BrandColors.navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back,
                size: 15, color: BrandColors.muted),
            label: const Text('Back to Login',
                style: TextStyle(fontSize: 13, color: BrandColors.muted)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
