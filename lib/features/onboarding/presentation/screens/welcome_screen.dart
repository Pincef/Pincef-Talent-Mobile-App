import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/brand_header.dart';

/// The TRUE marketing/landing entry point — distinct from ChooseRoleScreen
/// (the candidate/recruiter picker), which now only shows up after
/// "Get Started" is tapped here.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            if (!isWide) {
              // The photo/testimonial panel is decorative marketing
              // content — dropped on narrow screens rather than
              // squeezed in, so mobile just gets straight to the pitch.
              return const SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: _WelcomeContent(),
              );
            }

            return const Row(
              children: [
                Expanded(child: _WelcomeImagePanel()),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 56),
                      child: _WelcomeContent(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            LogoMark(),
            SizedBox(width: 8),
            // ASSUMPTION: screenshot's header text width suggests
            // "PINCEF TALENTBRIDGE" rather than just "TALENTBRIDGE" —
            // overlapping avatar-bubble artifacts in the screenshot make
            // it hard to confirm exactly. Revert to 'TALENTBRIDGE' if
            // this is wrong.
            Text(
              'PINCEF TALENTBRIDGE',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BrandColors.navy),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text('Global Talent Acquisition', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
        const SizedBox(height: 28),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            children: [
              TextSpan(text: 'Welcome to ', style: TextStyle(color: BrandColors.navy)),
              TextSpan(text: 'Pincef TalentBridge', style: TextStyle(color: BrandColors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'The intelligent ecosystem designed for global recruiters. Seamlessly '
          'manage your funnel, parse CVs with AI, and bridge the gap between '
          "world-class talent and your open roles.",
          style: TextStyle(fontSize: 13.5, color: BrandColors.muted, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/choose-role'),
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
                Text('Get Started', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: link to a real "learn more" page
                },
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text('Learn More', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.navy,
                  side: const BorderSide(color: BrandColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: wire an actual demo video/modal
                },
                icon: const Icon(Icons.play_circle_outline, size: 15),
                label: const Text('Watch Demo', style: TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.navy,
                  side: const BorderSide(color: BrandColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Left-hand photo/testimonial panel — desktop/wide only.
/// NOTE: no real backdrop photo asset yet, so this keeps the dark gradient
/// placeholder (per instruction, not adding a real image here). The logo
/// badge now reuses the actual `LogoMark()` widget — the same one used in
/// the header — scaled up, instead of a generic Material icon standing in
/// for it.
class _WelcomeImagePanel extends StatelessWidget {
  const _WelcomeImagePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF11182B), Color(0xFF1B2A4E)],
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Transform.scale(
              scale: 2.6,
              child: const LogoMark(),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE8F8EE), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text('ENTERPRISE READY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '"Pincef revolutionized how we source talent across three '
                  'continents. The AI matching is a game-changer."',
                  style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: BrandColors.navy, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: BrandColors.iconBg, child: Icon(Icons.person, size: 14, color: BrandColors.navy)),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sarah Miller', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BrandColors.navy)),
                        Text('Director of Talent, TechCorp', style: TextStyle(fontSize: 10, color: BrandColors.muted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              _StatBlock(value: '10k+', label: 'Global Placements'),
              SizedBox(width: 32),
              _StatBlock(value: '98%', label: 'Retention Rate'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BrandColors.orange)),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
      ],
    );
  }
}