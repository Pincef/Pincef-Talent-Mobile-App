import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/theme/brand_color.dart';
import '../../../../../../core/theme/auth_form_style.dart';
import '../../application/profile_setup_provider.dart';
import 'profile_setup_widgets.dart';

class ProfileStep2ProfessionalSummary extends ConsumerStatefulWidget {
  const ProfileStep2ProfessionalSummary({
    super.key,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  ConsumerState<ProfileStep2ProfessionalSummary> createState() =>
      _ProfileStep2ProfessionalSummaryState();
}

class _ProfileStep2ProfessionalSummaryState extends ConsumerState<ProfileStep2ProfessionalSummary> {
  static const _maxLength = 1000;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: ref.read(profileSetupProvider).bio)
      ..addListener(() => setState(() {})); // drives the live "x / 1000" counter
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    ref.read(profileSetupProvider.notifier).updateBio(_bioController.text);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final mainCard = WizardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Professional Summary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.navy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Introduce yourself to potential employers. Highlight your core expertise and what makes '
                'you the right fit for your next big role.',
                style: TextStyle(fontSize: 12.5, color: BrandColors.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bio / About Me',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BrandColors.navy),
                  ),
                  Text(
                    '${_bioController.text.length} / $_maxLength',
                    style: const TextStyle(fontSize: 11, color: BrandColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLines: 6,
                maxLength: _maxLength,
                buildCounter: (BuildContext context, {required int currentLength, required bool isFocused, int? maxLength}) => null,
                decoration: authInputDecoration(
                  hint: 'Example: I am a Senior UI/UX Designer with 8+ years of experience building scalable '
                      'design systems for fintech startups. I specialize in bridging the gap between complex '
                      'user needs and elegant technical solutions...',
                ),
                style: const TextStyle(color: BrandColors.navy, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: BrandColors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Need help? ',
                              style: TextStyle(fontWeight: FontWeight.w700, color: BrandColors.navy, fontSize: 12),
                            ),
                            TextSpan(
                              text: 'Start by mentioning your current title, years of experience, and your '
                                  'biggest career achievement.',
                              style: TextStyle(color: BrandColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              WizardFooterRow(
                onBack: widget.onBack,
                onSkip: widget.onSkip,
                skipLabel: 'SKIP FOR NOW',
                onPrimary: _saveAndContinue,
                primaryLabel: 'Continue',
              ),
            ],
          ),
        );

        const sidebar = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ApplicationFlowCard(currentStep: 1),
            SizedBox(height: 16),
            _TipsForSuccessCard(),
            SizedBox(height: 16),
            _SupportCard(),
          ],
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [mainCard, const SizedBox(height: 16), sidebar],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: mainCard),
            const SizedBox(width: 16),
            const SizedBox(width: 260, child: sidebar),
          ],
        );
      },
    );
  }
}

class _ApplicationFlowCard extends StatelessWidget {
  const _ApplicationFlowCard({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Personal Info', 'Professional Summary', 'Experience & Skills', 'Portfolio Upload'];

    return WizardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPLICATION FLOW',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BrandColors.muted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < labels.length; i++) ...[
            Row(
              children: [
                _FlowStepDot(index: i, currentStep: currentStep),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: i == currentStep ? FontWeight.w700 : FontWeight.w500,
                      color: i == currentStep ? BrandColors.navy : BrandColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            if (i != labels.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FlowStepDot extends StatelessWidget {
  const _FlowStepDot({required this.index, required this.currentStep});
  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    if (index < currentStep) {
      return const CircleAvatar(
        radius: 9,
        backgroundColor: Color(0xFF16A34A),
        child: Icon(Icons.check, size: 11, color: Colors.white),
      );
    }
    if (index == currentStep) {
      return const CircleAvatar(
        radius: 9,
        backgroundColor: BrandColors.orange,
        child: Icon(Icons.circle, size: 6, color: Colors.white),
      );
    }
    return CircleAvatar(
      radius: 9,
      backgroundColor: BrandColors.border,
      child: Text('${index + 1}', style: const TextStyle(fontSize: 9, color: BrandColors.muted)),
    );
  }
}

class _Tip {
  const _Tip(this.title, this.description);
  final String title;
  final String description;
}

const _tips = [
  _Tip('Focus on impact', 'Mention key achievements with numbers or specific results you delivered.'),
  _Tip('Keep it concise', '3-5 sentences is the sweet spot for a summary that recruiters will actually read.'),
  _Tip('Keywords matter', 'Use industry-standard terms relevant to the roles you are targeting.'),
];

class _TipsForSuccessCard extends StatelessWidget {
  const _TipsForSuccessCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BrandColors.navy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 10),
          const Text('Tips for success', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 12),
          for (final tip in _tips) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, size: 14, color: BrandColors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(tip.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: wire an actual support chat widget/route
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.forum_outlined, size: 16, color: BrandColors.navy),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Stuck? Chat with support',
                style: TextStyle(fontSize: 12.5, color: BrandColors.navy, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: BrandColors.navy),
          ],
        ),
      ),
    );
  }
}
