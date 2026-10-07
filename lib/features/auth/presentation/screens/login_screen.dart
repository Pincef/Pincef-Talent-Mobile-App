import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../application/auth_provider.dart';
import '../../../../core/widgets/app_toast.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // "Remember me" is UI-only right now — nothing persists it yet.
      // Hook it up once there's a place to act on it (e.g. token TTL,
      // or whether hasStoredSession() survives an app restart at all).
      await ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      AppToast.success(context, 'Signed in successfully.');
      if (!mounted) return;
      // Auth graduation, not a forward flow — replace so back doesn't
      // return to a stale login form.
      context.go('/dashboard');
    } catch (_) {
      final message = ref.read(authProvider).error;
      AppToast.error(
        context,
        message == null || message.trim().isEmpty
            ? 'Sign in failed. Check your details and try again.'
            : message.replaceFirst(RegExp(r'^Exception:\s*'), '').trim(),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BrandHeader(
                            title: 'Welcome Back',
                            subtitle:
                                'Manage your global talent funnel with ease.',
                          ),
                          const SizedBox(height: 24),
                          const Text('EMAIL ADDRESS', style: authLabelStyle),
                          const SizedBox(height: 6),
                          TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: authInputDecoration(
                                  hint: 'you@company.com',
                                  icon: Icons.mail_outline),
                              validator: emailValidator,
                              style: const TextStyle(color: BrandColors.navy)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PASSWORD', style: authLabelStyle),
                              TextButton(
                                onPressed: () =>
                                    context.push('/forgot-password'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: BrandColors.orange,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
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
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Password is required';
                              return null;
                            },
                            style: const TextStyle(color: BrandColors.navy),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(
                                      () => _rememberMe = value ?? false),
                                  activeColor: BrandColors.orange,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Remember me for 30 days',
                                style: TextStyle(
                                    fontSize: 12.5, color: BrandColors.muted),
                              ),
                            ],
                          ),
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
                                : const Text('Sign In',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 18),
                          const Row(
                            children: [
                              Expanded(
                                  child: Divider(color: BrandColors.border)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: TextStyle(
                                      color: BrandColors.muted,
                                      fontSize: 11,
                                      letterSpacing: 0.3),
                                ),
                              ),
                              Expanded(
                                  child: Divider(color: BrandColors.border)),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () {
                              // TODO: wire Google sign-in once you have an OAuth flow
                            },
                            icon: const Icon(Icons.g_mobiledata, size: 22),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BrandColors.navy,
                              side: const BorderSide(color: BrandColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                      fontSize: 13, color: BrandColors.muted),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/welcome'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: BrandColors.orange,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
}
