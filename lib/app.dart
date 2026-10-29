import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/api_loading_provider.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_toast.dart';

class TalentBridgeApp extends ConsumerWidget {
  const TalentBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TalentBridge',
      theme: appTheme,
      scaffoldMessengerKey: AppToast.messengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final isLoading = ref.watch(isApiLoadingProvider);
        final authState = ref.watch(authProvider);
        final isGuestInvite =
            router.routerDelegate.currentConfiguration.uri.path ==
                '/interview-guest';
        if (!isGuestInvite &&
            (authState.isRestoringSession || authState.sessionRestoreFailed)) {
          return Material(
            color: Colors.white,
            child: Center(
              child: authState.sessionRestoreFailed
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 40, color: Color(0xFF687386)),
                            const SizedBox(height: 16),
                            const Text(
                              'Reconnecting to your account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authState.error ??
                                  'Check your connection and try again.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
                              onPressed: () => ref
                                  .read(authProvider.notifier)
                                  .retrySessionRestore(),
                              child: const Text('Try again'),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(authProvider.notifier)
                                  .clearFailedSession(),
                              child: const Text('Sign in with another account'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Stack(
          children: [
            child!,
            if (isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        );
      },
    );
  }
}
