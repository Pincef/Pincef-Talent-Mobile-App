import 'package:flutter/material.dart';
import '../theme/brand_color.dart';

/// Shared chrome for "add/edit" modals across the app — a small icon +
/// title + optional subtitle at the top, a close (X) button, your form
/// content in the middle, and a Cancel / primary-action footer.
///
/// Built after the "Add Education History" and "Add Portfolio Link"
/// modals in the candidate profile-setup wizard, but intentionally
/// generic — any future "add X" modal (a recruiter job posting, a
/// candidate skill, whatever comes next) can reuse this shell instead of
/// re-building the same dialog chrome each time.
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => const EducationHistoryModal(), // wraps FormModalShell internally
/// );
/// ```
class FormModalShell extends StatelessWidget {
  const FormModalShell({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onCancel,
    required this.onPrimaryPressed,
    required this.primaryLabel,
    this.cancelLabel = 'Cancel',
    this.isSubmitting = false,
    this.maxWidth = 440,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback? onPrimaryPressed;
  final String primaryLabel;
  final String cancelLabel;

  /// When true, disables both footer buttons and shows a spinner on the
  /// primary one — for once these modals call a real backend endpoint.
  final bool isSubmitting;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: BrandColors.iconBg, borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, size: 16, color: BrandColors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BrandColors.navy),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
                          ],
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: isSubmitting ? null : onCancel,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: BrandColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.navy,
                          side: const BorderSide(color: BrandColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(cancelLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : onPrimaryPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}