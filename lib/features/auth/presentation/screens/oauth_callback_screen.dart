import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/auth_provider.dart';

class OAuthCallbackScreen extends ConsumerStatefulWidget {
  const OAuthCallbackScreen({super.key, required this.code, required this.error});

  final String? code;
  final String? error;

  @override
  ConsumerState<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends ConsumerState<OAuthCallbackScreen> {
  String? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  Future<void> _finish() async {
    if (widget.error != null || widget.code == null || widget.code!.isEmpty) {
      if (mounted) setState(() => _failure = 'Google sign-in could not be completed. Please try again.');
      return;
    }
    try {
      await ref.read(authProvider.notifier).completeGoogleOAuth(widget.code!);
      if (mounted) {
        final user = ref.read(authProvider).user;
        context.go(user?.needsCompanySetup == true ? '/recruiter-company-setup' : '/dashboard');
      }
    } catch (_) {
      if (mounted) setState(() => _failure = 'The sign-in link expired or was already used. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _failure == null
            ? const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Completing Google sign-in…'),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: Colors.deepOrange, size: 36),
                const SizedBox(height: 12),
                Text(_failure!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
              ]),
      ),
    );
  }
}
