import 'package:flutter/material.dart';
import '../../../../../../core/theme/brand_color.dart';

/// Section names shown top-right of the wizard header on each step —
/// order matches ProfileSetupState.step (0-indexed).
const List<String> kProfileSetupSectionLabels = [
  'Profile & Summary',
  'Experience & Verification',
];

/// "STEP X OF 4" + section name + the 4-segment progress track.
///
/// ASSUMPTION: every screenshot of this flow shows "STEP 1 OF 4" verbatim,
/// even on steps 2-4 (only the segment fill and the section label change
/// there). That reads as a mock/export bug rather than intent, so this
/// counts up properly instead ("STEP 2 OF 4", etc.) — flag it if the
/// literal "1" was actually deliberate.
class WizardStepHeader extends StatelessWidget {
  const WizardStepHeader({super.key, required this.step});

  /// 0-indexed (0 == Step 1 of 4).
  final int step;

  @override
  Widget build(BuildContext context) {
    const total = 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STEP ${step + 1} OF $total',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: BrandColors.orange,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              kProfileSetupSectionLabels[step],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BrandColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(total, (i) {
            final filled = i <= step;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: filled ? BrandColors.orange : BrandColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// White rounded card shell reused by every wizard step — same visual
/// language as the auth screens' form container.
class WizardCard extends StatelessWidget {
  const WizardCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.border),
      ),
      child: child,
    );
  }
}

/// Shared footer row: optional Back on the left, optional Skip in the
/// middle-right, Continue/Complete on the far right. Skip label/color are
/// parameterized since the mocks aren't consistent about it — plain grey
/// "Skip for now" on step 1, all-caps grey on step 2, orange on step 3.
class WizardFooterRow extends StatelessWidget {
  const WizardFooterRow({
    super.key,
    this.onBack,
    this.onSkip,
    this.skipLabel = 'Skip for now',
    this.skipColor = BrandColors.muted,
    required this.onPrimary,
    required this.primaryLabel,
    this.primaryIcon = Icons.arrow_forward,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String skipLabel;
  final Color skipColor;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final IconData primaryIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back,
                size: 15, color: BrandColors.muted),
            label: const Text('Back',
                style: TextStyle(fontSize: 13, color: BrandColors.muted)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          const SizedBox.shrink(),
        const Spacer(),
        if (onSkip != null) ...[
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              skipLabel,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: skipColor),
            ),
          ),
          const SizedBox(width: 20),
        ],
        ElevatedButton(
          onPressed: onPrimary,
          style: ElevatedButton.styleFrom(
            backgroundColor: BrandColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(primaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Icon(primaryIcon, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}
