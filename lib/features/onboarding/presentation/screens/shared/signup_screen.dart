import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/brand_color.dart';
import '../../../../../core/theme/auth_form_style.dart';
import '../../../../../core/widgets/brand_header.dart';
import '../../../../onboarding/application/selected_role_provider.dart';
import '../../../../auth/application/auth_provider.dart';
import '../../../../auth/data/models/user_model.dart';
import '../../../../../core/widgets/app_toast.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final role = ref.read(selectedRoleProvider);
    if (role == null) {
      // Shouldn't happen if navigation always goes through /welcome first,
      // but guard rather than send a null role to the backend.
      setState(() =>
          _errorText = 'Please choose a role from the welcome screen first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      // For recruiters, this is also the recruiter's own name — the
      // recruiter company-setup screen only collects the company's
      // name, not the person's, so this is the one place that gets
      // captured.
      await ref.read(authProvider.notifier).signUp(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: role,
          );

      if (!mounted) return;
      AppToast.success(context, 'Account created successfully.');
      context.go(
        role == UserRole.recruiter
            ? '/recruiter-company-setup'
            : '/candidate-profile-setup',
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(
            context, 'Could not create your account. Please try again.');
        setState(() => _errorText = 'Something went wrong. Please try again.');
      }
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
              child: Container(
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
                        title: 'Sign Up',
                        subtitle: 'Create your account to get started',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('FIRST NAME', style: authLabelStyle),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _firstNameController,
                                  decoration: authInputDecoration(
                                      hint: 'Ada', icon: Icons.person_outline),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                  style:
                                      const TextStyle(color: BrandColors.navy),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LAST NAME', style: authLabelStyle),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _lastNameController,
                                  decoration: authInputDecoration(
                                      hint: 'Lovelace',
                                      icon: Icons.person_outline),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                  style:
                                      const TextStyle(color: BrandColors.navy),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('EMAIL ADDRESS', style: authLabelStyle),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: authInputDecoration(
                            hint: 'you@example.com', icon: Icons.mail_outline),
                        validator: emailValidator,
                        style: const TextStyle(color: BrandColors.navy),
                      ),
                      const SizedBox(height: 16),
                      const Text('PASSWORD', style: authLabelStyle),
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
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8) {
                            return 'Use at least 8 characters';
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
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) {
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
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12.5)),
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
                            : const Text('Sign Up',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: BrandColors.border)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('or',
                                style: TextStyle(
                                    color: BrandColors.muted, fontSize: 12.5)),
                          ),
                          Expanded(child: Divider(color: BrandColors.border)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () {
                          // TODO: wire Google sign-up once you have an OAuth flow
                        },
                        icon: const Icon(Icons.g_mobiledata, size: 22),
                        label: const Text('Continue with Google'),
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
                              'Already have an account? ',
                              style: TextStyle(
                                  fontSize: 13, color: BrandColors.muted),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Log in',
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
            ),
          ),
        ),
      ),
    );
  }
}
