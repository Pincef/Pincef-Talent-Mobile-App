import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/api_loading_provider.dart';
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
