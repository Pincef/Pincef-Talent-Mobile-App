import 'package:flutter/material.dart';
import '../theme/brand_color.dart';

class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: BrandColors.border),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              '© ${DateTime.now().year} Pincef TalentBridge. All rights reserved.',
              style: const TextStyle(fontSize: 11, color: BrandColors.muted),
            ),
            const Text('Privacy Policy', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
            const Text('Terms of Service', style: TextStyle(fontSize: 11, color: BrandColors.muted)),
          ],
        ),
      ],
    );
  }
}