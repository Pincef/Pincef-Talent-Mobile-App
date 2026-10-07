import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/theme/brand_color.dart';
import 'profile_setup_widgets.dart';

class ProfileStep3Experience extends ConsumerWidget {
  const ProfileStep3Experience({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Build your career timeline',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your professional experience to help our matching engine find the roles that align with '
            'your seniority and technical expertise.',
            style: TextStyle(
                fontSize: 12.5, color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: BrandColors.background,
              borderRadius: BorderRadius.circular(12),
              // NOTE: mock shows a dashed border here — approximated as
              // solid for the same reason noted on the profile-picture
              // picker (no dashed-border package confirmed available).
              border: Border.all(color: BrandColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: BrandColors.iconBg, shape: BoxShape.circle),
                  child: const Icon(Icons.work_outline,
                      color: BrandColors.navy, size: 20),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No roles added yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy,
                      fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Start building your profile by adding your current or previous work experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: BrandColors.muted, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // OPEN ISSUE: no design has been shared yet for the
                    // "add role" form (title/company/dates/description) —
                    // wire this once that exists. Stubbed with a snackbar
                    // for now so the button isn't a silent no-op.
                    AppToast.info(context, 'Add-role form coming soon.');
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add First Role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: BrandColors.border),
          const SizedBox(height: 16),
          WizardFooterRow(
            onBack: onBack,
            onSkip: onSkip,
            // Matches this step's mock specifically — "Skip for now" reads
            // orange here, unlike steps 1-2 where it's muted grey.
            skipColor: BrandColors.orange,
            onPrimary: onContinue,
            primaryLabel: 'Continue',
          ),
        ],
      ),
    );
  }
}
