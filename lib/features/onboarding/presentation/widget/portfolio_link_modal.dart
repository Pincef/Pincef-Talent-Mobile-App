import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/form_shell.dart';
import '../../application/profile_setup_provider.dart';
import '../../data/models/profile_setup_models.dart';

/// Not wired to a trigger yet — there's no "Portfolio Links" section in
/// the current Step 4 layout to open this from (the four screenshots the
/// wizard was built against only showed Education History +
/// Certifications). Built ready-to-use per your note that this'll be
/// useful later — wire a button to:
/// ```dart
/// showDialog(context: context, builder: (_) => const PortfolioLinkModal());
/// ```
/// whenever a Portfolio section gets designed. Submitted entries land in
/// profileSetupProvider's `portfolioLinks` list either way.
class PortfolioLinkModal extends ConsumerStatefulWidget {
  const PortfolioLinkModal({super.key});

  @override
  ConsumerState<PortfolioLinkModal> createState() => _PortfolioLinkModalState();
}

class _PortfolioLinkModalState extends ConsumerState<PortfolioLinkModal> {
  // ASSUMPTION: exact platform list isn't visible in the mock (the
  // dropdown is shown collapsed, just "Select Platform") — using a
  // reasonable set for a design/dev candidate's portfolio. Adjust freely.
  static const _platforms = ['Behance', 'Dribbble', 'GitHub', 'Personal Website', 'LinkedIn', 'Other'];

  String? _platform;
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (_platform == null || url.isEmpty) {
      setState(() => _errorText = 'Platform and Link URL are required.');
      return;
    }
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      setState(() => _errorText = 'Enter a full URL, starting with https://');
      return;
    }

    // Local-only now — goes out with everything else at Step 4's
    // "Complete Profile", not on its own.
    ref.read(profileSetupProvider.notifier).addPortfolioLink(
          PortfolioLinkEntry(
            platform: _platform!,
            url: url,
            displayTitle: _titleController.text.trim(),
          ),
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormModalShell(
      icon: Icons.link,
      title: 'Add Portfolio Link',
      subtitle: 'Showcase your creative work to potential recruiters.',
      onCancel: () => Navigator.of(context).pop(),
      onPrimaryPressed: _submit,
      primaryLabel: 'Add to Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('PLATFORM NAME', style: authLabelStyle),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _platform,
            dropdownColor: Colors.white,
            decoration: authInputDecoration(hint: 'Select Platform'),
            style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
            items: _platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _platform = v),
          ),
          const SizedBox(height: 14),
          const Text('LINK URL', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: authInputDecoration(hint: 'https://...', icon: Icons.link),
            style: const TextStyle(color: BrandColors.navy),
          ),
          const SizedBox(height: 14),
          const Text('DISPLAY TITLE', style: authLabelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleController,
            decoration: authInputDecoration(hint: 'e.g., My UI Design Case Studies'),
            style: const TextStyle(color: BrandColors.navy),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}