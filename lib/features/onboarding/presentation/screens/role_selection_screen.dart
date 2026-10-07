import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../auth/data/models/user_model.dart';
import '../../application/selected_role_provider.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48 : 20,
                vertical: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 40),
                      const _HeroText(),
                      const SizedBox(height: 40),
                      isWide
                          ? const IntrinsicHeight(
                              // Row + crossAxisAlignment.stretch needs a
                              // finite height to stretch to. Without this,
                              // the Column-inside-SingleChildScrollView
                              // above gives the Row an UNBOUNDED height
                              // (0..Infinity), which crashes with
                              // "BoxConstraints forces an infinite height"
                              // the moment stretch tries to size the cards.
                              // IntrinsicHeight computes a real height from
                              // the taller card first, which is also what
                              // makes both cards end up the same height.
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _CandidateCard()),
                                  SizedBox(width: 24),
                                  Expanded(child: _RecruiterCard()),
                                ],
                              ),
                            )
                          : const Column(
                              children: [
                                _CandidateCard(),
                                SizedBox(height: 20),
                                _RecruiterCard(),
                              ],
                            ),
                      const SizedBox(height: 32),
                      const _SignInFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Empower Your Professional Journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: BrandColors.navy,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Text(
            "Whether you're looking for your next career milestone or seeking "
            "the industry's finest talent, TalentBridge provides the tools to succeed.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, color: BrandColors.muted, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// Shared card shell so both roles stay visually identical —
/// only the content, icon, and CTA differ.
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final Widget cta;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BrandColors.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: BrandColors.navy, size: 22),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BrandColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              color: BrandColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 17, color: BrandColors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 13.5, color: BrandColors.navy),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: cta),
        ],
      ),
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RoleCard(
      icon: Icons.person_outline,
      title: 'Join as a Candidate',
      description: 'Find your dream role with AI-powered matching and career tools.',
      features: const [
        'Personalized job recommendations',
        'Direct communication with hiring managers',
        'AI resume optimization tools',
      ],
      cta: OutlinedButton(
        onPressed: () {
          ref.read(selectedRoleProvider.notifier).state = UserRole.candidate;
          context.go('/signup');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.navy,
          side: const BorderSide(color: BrandColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _RecruiterCard extends ConsumerWidget {
  const _RecruiterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _RoleCard(
      icon: Icons.business_center_outlined,
      title: 'Join as a Recruiter',
      description:
          'Source top-tier talent and manage your hiring funnel with enterprise-grade efficiency.',
      features: const [
        'Automated candidate screening',
        'Collaborative hiring workflows',
        'Predictive retention analytics',
      ],
      cta: ElevatedButton(
        onPressed: () {
          ref.read(selectedRoleProvider.notifier).state = UserRole.recruiter;
          context.go('/signup');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Create Recruiter Account', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SignInFooter extends StatelessWidget {
  const _SignInFooter();

  @override
  Widget build(BuildContext context) {
    // Not present in the mockup, but a welcome screen typically needs a
    // way back to sign-in for returning users — remove if not wanted.
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Already have an account? ',
            style: TextStyle(fontSize: 13.5, color: BrandColors.muted),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(
                fontSize: 13.5,
                color: BrandColors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}