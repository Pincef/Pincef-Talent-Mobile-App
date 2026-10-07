import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/brand_color.dart';

/// Shown after local credentials have been cleared. Navigation is deliberately
/// owned by the caller so this presentation widget stays reusable.
Future<void> showLogoutSuccessDialog(
  BuildContext context, {
  required VoidCallback onSignInAgain,
  required VoidCallback onReturnHome,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: .24),
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        decoration: const BoxDecoration(
                          color: BrandColors.navy,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Image.asset('lib/assets/images/logo.jpeg'),
                      ),
                      const SizedBox(width: 7),
                      const Text('PINCEF TALENTBRIDGE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text('Global Talent Acquisition', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 2, thickness: 2, color: AppColors.orange),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: Color(0xFFEAF2FF), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.orange),
                  ),
                  const SizedBox(height: 14),
                  const Text('Logged Out Successfully', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 7),
                  const Text('Thank you for using Pincef TalentBridge. Your\nsession has been securely cleared.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, height: 1.45, color: AppColors.textSecondary)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSignInAgain,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), padding: const EdgeInsets.symmetric(vertical: 10)),
                      child: const Text('Sign In Again  →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onReturnHome, child: const Text('Return to Homepage', style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary))),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
