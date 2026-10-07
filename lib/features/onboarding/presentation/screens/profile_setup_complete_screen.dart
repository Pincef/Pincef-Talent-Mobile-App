import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../application/profile_setup_provider.dart';

/// Shown after Step 4's "Complete Profile" call succeeds (a real 200 from
/// the backend, once that endpoint exists) — before landing on the
/// dashboard. See candidate_profile_setup_screen.dart for the navigation
/// trigger.
///
/// ADAPTED FROM MOCK: the screenshot this was built from ("Ready to
/// Recruit!") is written for a recruiter's onboarding-complete moment
/// (talent-pool sync, "+ New Job", etc). This is the candidate-side
/// equivalent — same layout/chrome, reworded copy. The two stat numbers
/// below (match score, etc.) are placeholders until a real
/// scoring/verification backend exists — same caveat as Step 4's summary
/// card.
class ProfileSetupCompleteScreen extends ConsumerWidget {
  const ProfileSetupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(profileSetupProvider).firstNameOrFallback;

    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 16),
                  const _OnboardingCompleteBadge(),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BrandColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your profile is ready, $firstName!',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BrandColors.navy),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Your talent profile is fully set up and ready for recruiters.',
                                    style: TextStyle(fontSize: 12, color: BrandColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Everything's in place. We've indexed your profile, education, and certifications, "
                          'and activated AI-powered matching so recruiters searching for your skills can find you.',
                          style: TextStyle(fontSize: 12.5, color: BrandColors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StatBox(
                                icon: Icons.bolt,
                                label: 'PROFILE COMPLETE',
                                description: 'Your details are visible to recruiters searching for your skills.',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _StatBox(
                                icon: Icons.trending_up,
                                label: 'MATCH READINESS',
                                // NOTE: same 94% placeholder used on Step 4's
                                // summary card — hardcoded until a real
                                // scoring backend exists.
                                description: '94% ready based on your current profile.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.go('/dashboard'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // TODO: no "view my profile" route exists
                                  // yet — wire once that screen is built.
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: BrandColors.navy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('View My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: BrandColors.muted),
                              children: [
                                const TextSpan(text: 'Need a walkthrough? '),
                                TextSpan(
                                  text: 'View Onboarding Guide',
                                  style: const TextStyle(color: BrandColors.orange, fontWeight: FontWeight.w600),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // TODO: no onboarding guide exists yet
                                      // — wire once that content is ready.
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class _OnboardingCompleteBadge extends StatelessWidget {
  const _OnboardingCompleteBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 20,
            height: 4,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(2)),
          ),
        const SizedBox(width: 8),
        const Text(
          'ONBOARDING COMPLETE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A), letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.description});

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: BrandColors.orange),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: BrandColors.navy, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(description, style: const TextStyle(fontSize: 10.5, color: BrandColors.muted, height: 1.3)),
        ],
      ),
    );
  }
}