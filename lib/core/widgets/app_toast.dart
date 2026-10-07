import 'package:flutter/material.dart';

enum AppToastKind { success, error, info }

/// Consistent, brief feedback for completed or failed user actions.
abstract final class AppToast {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.success);

  static void error(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.error);

  static void info(BuildContext context, String message) =>
      show(context, message, kind: AppToastKind.info);

  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.info,
  }) {
    final messenger =
        messengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
    if (messenger == null || message.trim().isEmpty) return;
    final (color, icon) = switch (kind) {
      AppToastKind.success => (
          const Color(0xFF087F5B),
          Icons.check_circle_outline
        ),
      AppToastKind.error => (const Color(0xFFB42318), Icons.error_outline),
      AppToastKind.info => (const Color(0xFF172554), Icons.info_outline),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
