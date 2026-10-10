import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/recruiter_profile_setup_provider.dart';

class RecruiterProfileSetupScreen extends ConsumerStatefulWidget {
  const RecruiterProfileSetupScreen({super.key});

  @override
  ConsumerState<RecruiterProfileSetupScreen> createState() =>
      _RecruiterProfileSetupScreenState();
}

class _RecruiterProfileSetupScreenState
    extends ConsumerState<RecruiterProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _websiteController = TextEditingController();

  // ASSUMPTION: exact option lists aren't visible in the mock (both
  // dropdowns render collapsed with empty `items: []`) — using
  // reasonable placeholder sets. Swap for the real lists whenever
  // they're confirmed.
  static const _industries = [
    'Technology',
    'Finance',
    'Healthcare',
    'Education',
    'Retail',
    'Manufacturing',
    'Other'
  ];
  static const _companySizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1000+'
  ];

  String? _industry;
  String? _companySize;
  Uint8List? _logoBytes;
  String? _logoFilename;

  @override
  void dispose() {
    _companyNameController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    // Gallery-only (no camera option) — a company logo is virtually
    // always an existing file, not something photographed on the spot,
    // unlike the candidate profile-photo picker in Step 1.
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 90);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
    _logoFilename = picked.name;
    ref.read(recruiterProfileSetupProvider.notifier).updateLogo(bytes);
  }

  void _removeLogo() {
    setState(() => _logoBytes = null);
    _logoFilename = null;
    ref.read(recruiterProfileSetupProvider.notifier).removeLogo();
  }

  String? _websiteValidator(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // optional field
    if (!(v.startsWith('http://') || v.startsWith('https://'))) {
      return 'Enter a full URL, starting with https://';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success =
        await ref.read(recruiterProfileSetupProvider.notifier).submit(
              companyName: _companyNameController.text.trim(),
              industry: _industry,
              companySize: _companySize,
              companyWebsite: _websiteController.text.trim(),
              logoFilename: _logoFilename,
            );

    if (!mounted) return;

    if (success) {
      AppToast.success(context, 'Company profile saved.');
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } else {
      final error = ref.read(recruiterProfileSetupProvider).saveError;
      AppToast.error(
          context, error ?? 'Failed to save profile. Please try again.');
    }
  }

  Widget _companyNameField() => _LabeledField(
        label: 'COMPANY NAME',
        child: TextFormField(
          controller: _companyNameController,
          decoration: authInputDecoration(
            hint: 'e.g. Acme Corporation',
            icon: Icons.business_outlined,
          ),
          style: const TextStyle(color: BrandColors.navy),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Company name is required'
              : null,
        ),
      );

  Widget _industryField() => _LabeledField(
        label: 'INDUSTRY',
        child: DropdownButtonFormField<String>(
          initialValue: _industry,
          isExpanded: true,
          dropdownColor: Colors.white,
          decoration: authInputDecoration(
            hint: 'Select industry',
            icon: Icons.apartment_outlined,
          ),
          style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
          items: _industries
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => setState(() => _industry = v),
        ),
      );

  Widget _companySizeField() => _LabeledField(
        label: 'COMPANY SIZE',
        child: DropdownButtonFormField<String>(
          initialValue: _companySize,
          isExpanded: true,
          dropdownColor: Colors.white,
          decoration: authInputDecoration(
            hint: 'Select size',
            icon: Icons.groups_outlined,
          ),
          style: const TextStyle(color: BrandColors.navy, fontSize: 13.5),
          items: _companySizes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _companySize = v),
        ),
      );

  Widget _websiteField() => _LabeledField(
        label: 'COMPANY WEBSITE',
        child: TextFormField(
          controller: _websiteController,
          keyboardType: TextInputType.url,
          decoration: authInputDecoration(
            hint: 'https://www.acme.com',
            icon: Icons.language_outlined,
          ),
          style: const TextStyle(color: BrandColors.navy),
          validator: _websiteValidator,
        ),
      );

  Widget _submitButton(bool isSaving) => ElevatedButton(
        onPressed: isSaving ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Next Step',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
      );

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final isSaving =
        ref.watch(recruiterProfileSetupProvider.select((s) => s.isSaving));

    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 24,
              vertical: isCompact ? 20 : 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 20 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: BrandColors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const BrandHeader(
                            title: 'Set up your Profile',
                            subtitle:
                                'Tell us a bit about your organization to personalize your talent acquisition dashboard.',
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'PROFILE PICTURE (OPTIONAL)',
                            style: authLabelStyle,
                          ),
                          const SizedBox(height: 8),
                          _ImageUploadBox(
                            logoBytes: _logoBytes,
                            onTap: _pickLogo,
                            onRemove: _logoBytes != null ? _removeLogo : null,
                          ),
                          const SizedBox(height: 28),
                          isCompact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _companyNameField(),
                                    const SizedBox(height: 20),
                                    _industryField(),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _companyNameField()),
                                    const SizedBox(width: 20),
                                    Expanded(child: _industryField()),
                                  ],
                                ),
                          const SizedBox(height: 20),
                          isCompact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _companySizeField(),
                                    const SizedBox(height: 20),
                                    _websiteField(),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _companySizeField()),
                                    const SizedBox(width: 20),
                                    Expanded(child: _websiteField()),
                                  ],
                                ),
                          const SizedBox(height: 28),
                          const Divider(color: BrandColors.border),
                          const SizedBox(height: 18),
                          isCompact
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextButton(
                                      onPressed: isSaving
                                          ? null
                                          : () => context.go('/dashboard'),
                                      child: const Text('Skip for now'),
                                    ),
                                    const SizedBox(height: 8),
                                    _submitButton(isSaving),
                                  ],
                                )
                              : Row(
                                  children: [
                                    TextButton(
                                      onPressed: isSaving
                                          ? null
                                          : () => context.go('/dashboard'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'Skip for now',
                                        style: TextStyle(
                                          color: BrandColors.muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                        width: 170,
                                        child: _submitButton(isSaving)),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: authLabelStyle),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ImageUploadBox extends StatelessWidget {
  const _ImageUploadBox({
    required this.logoBytes,
    required this.onTap,
    this.onRemove,
  });

  final Uint8List? logoBytes;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFF3CBA5),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: logoBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.memory(logoBytes!, fit: BoxFit.contain),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: onRemove,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFFFF4EB),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        color: BrandColors.orange,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Click to upload or drag and drop',
                      style: TextStyle(
                        color: BrandColors.navy,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      // NOTE: dropped "SVG" from the accepted-formats line
                      // — image_picker works with raster images (PNG/JPG)
                      // via the OS gallery; SVG needs a separate
                      // file_picker + SVG-preview path, which is more
                      // than this upload box currently does. Flag if SVG
                      // support is actually required.
                      'PNG, JPG (max. 800x400px)',
                      style: TextStyle(
                        fontSize: 12,
                        color: BrandColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
