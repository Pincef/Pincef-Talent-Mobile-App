import 'package:flutter/material.dart';
import '../theme/brand_color.dart';

class LogoMark extends StatelessWidget {
  const LogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      // decoration: const BoxDecoration(color: BrandColors.navy, shape: BoxShape.circle),
      // child: const Icon(Icons.groups_rounded, color: Colors.white, size: 15),
      child: Image.asset('lib/assets/images/white-logo.jpg'),
    );
  }
}

/// Logo + wordmark + tagline, with an optional title/subtitle block below
/// for form screens (Sign Up / Welcome Back / Forgot your password?).
/// Leave [title] null to get just the brand block on its own — that's
/// what the welcome screen uses, since its hero text is visually
/// distinct enough (larger, width-constrained) to stay screen-local.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.title,
    this.subtitle,
    this.titleFontSize = 22,
    this.subtitleMaxWidth,
  });

  final String? title;
  final String? subtitle;
  final double titleFontSize;
  final double? subtitleMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LogoMark(),
            SizedBox(width: 8),
            Text(
              'PINCEF TALENTBRIDGE',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BrandColors.navy),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Global Talent Acquisition', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
        if (title != null) ...[
          const SizedBox(height: 20),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800, color: BrandColors.navy),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: subtitleMaxWidth ?? double.infinity),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: BrandColors.muted, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}