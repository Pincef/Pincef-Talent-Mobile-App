import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../../core/theme/auth_form_style.dart';
import '../../../../core/widgets/brand_footer.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../application/profile_setup_provider.dart';
import '../../data/models/profile_setup_models.dart';
import '../widget/profile_setup_widgets.dart';
import '../widget/location_modal.dart';
import '../widget/work_experience_modal.dart';
import '../widget/education_history_modal.dart';

/// The candidate onboarding wizard — 2 steps ("Profile & Summary",
/// "Experience & Verification"), per the client's design. Supersedes both
/// the original 4-step wizard and the single-page "Launch Your Career"
/// redesign from two rounds ago; those extra fields (Highest
/// Qualification, Years of Experience, Core Skills, CV Upload, Terms
/// checkbox) aren't in this design and aren't rendered here — the
/// underlying state/backend fields for them are left in place (harmless)
/// in case they need a home elsewhere later.
///
/// Location keeps the real backend-driven Country/State/City search from
/// last round (see location_picker_modal.dart) behind a single tappable
/// field, matching the design's "one field" look without losing that
/// functionality. "Stuck? Let AI help" on the Bio field is dropped
/// entirely — no such backend feature exists. Certificates stay PDF-only
/// (backend constraint) with copy corrected to match.
class CandidateProfileSetupScreen extends ConsumerStatefulWidget {
  const CandidateProfileSetupScreen({super.key});

  @override
  ConsumerState<CandidateProfileSetupScreen> createState() =>
      _CandidateProfileSetupScreenState();
}

class _CandidateProfileSetupScreenState
    extends ConsumerState<CandidateProfileSetupScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _titleController;
  late final TextEditingController _bioController;
  late final TextEditingController _websiteController;
  late final TextEditingController _dribbbleController;

  String? _countryCode;
  String? _countryName;
  String? _stateCode;
  String? _stateName;
  String? _city;
  bool _isRemote = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(profileSetupProvider);
    _fullNameController = TextEditingController(text: state.fullName);
    _titleController = TextEditingController(text: state.professionalTitle);
    _bioController = TextEditingController(text: state.bio)
      ..addListener(
          () => setState(() {})); // drives the live "x / 1000" counter
    _websiteController = TextEditingController(text: state.personalWebsiteUrl);
    _dribbbleController = TextEditingController(text: state.dribbbleBehanceUrl);
    _countryCode = state.countryCode;
    _countryName = state.countryName;
    _stateCode = state.stateCode;
    _stateName = state.stateName;
    _city = state.city;
    _isRemote = state.city == 'Remote' && state.countryCode == null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _dribbbleController.dispose();
    super.dispose();
  }

  void _exitToDashboard() => context.go('/dashboard');

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    ref.read(profileSetupProvider.notifier).updateProfileImage(bytes);
  }

  Future<void> _openLocationPicker() async {
    final result = await showLocationPickerModal(
      context,
      initial: LocationSelection(
        countryCode: _countryCode,
        countryName: _countryName,
        stateCode: _stateCode,
        stateName: _stateName,
        city: _city,
        isRemote: _isRemote,
      ),
    );
    if (result == null) return;

    setState(() {
      _countryCode = result.countryCode;
      _countryName = result.countryName;
      _stateCode = result.stateCode;
      _stateName = result.stateName;
      _city = result.city;
      _isRemote = result.isRemote;
    });

    ref.read(profileSetupProvider.notifier).updateLocation(
          countryCode: result.countryCode,
          countryName: result.countryName,
          stateCode: result.stateCode,
          stateName: result.stateName,
          city: result.city,
        );
  }

  String get _locationDisplay {
    if (_isRemote) return 'Remote';
    return [_city, _stateName, _countryName]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .join(', ');
  }

  Future<void> _pickCertificate() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    ref
        .read(profileSetupProvider.notifier)
        .addCertification(bytes: bytes, filename: result.files.single.name);
  }

  void _continueToExperience() {
    final notifier = ref.read(profileSetupProvider.notifier);
    notifier.updatePersonalInfo(
      fullName: _fullNameController.text.trim(),
      professionalTitle: _titleController.text.trim(),
    );
    notifier.updateBio(_bioController.text);
    notifier.next();
  }

  Future<void> _completeProfile() async {
    final notifier = ref.read(profileSetupProvider.notifier);
    notifier.updatePersonalWebsiteUrl(_websiteController.text.trim());
    notifier.updateDribbbleBehanceUrl(_dribbbleController.text.trim());

    final success = await notifier.completeProfile();
    if (!mounted) return;

    if (success) {
      AppToast.success(context, 'Profile completed successfully.');
      context.go('/profile-setup-complete');
    } else {
      final error = ref.read(profileSetupProvider).saveError;
      AppToast.error(
          context, error ?? 'Failed to complete profile. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileSetupProvider);
    final notifier = ref.read(profileSetupProvider.notifier);

    Widget stepContent;
    if (state.step == 0) {
      stepContent = _ProfileSummaryStep(
        fullNameController: _fullNameController,
        titleController: _titleController,
        bioController: _bioController,
        profileImageBytes: state.profileImageBytes,
        onPickPhoto: _pickProfilePhoto,
        locationDisplay: _locationDisplay,
        onTapLocation: _openLocationPicker,
        onBack: _exitToDashboard,
        onContinue: _continueToExperience,
      );
    } else {
      stepContent = _ExperienceVerificationStep(
        workExperiences: state.workExperiences,
        onAddExperience: () => showDialog(
          context: context,
          builder: (_) => const WorkExperienceModal(),
        ),
        onRemoveExperience: notifier.removeWorkExperience,
        educationHistory: state.educationHistory,
        onAddEducation: () => showDialog(
          context: context,
          builder: (_) => const EducationHistoryModal(),
        ),
        onRemoveEducation: notifier.removeEducationEntry,
        websiteController: _websiteController,
        dribbbleController: _dribbbleController,
        certifications: state.certifications,
        onUploadCertificate: _pickCertificate,
        onRemoveCertificate: notifier.removeCertification,
        onBack: notifier.back,
        onComplete: state.isSaving ? null : _completeProfile,
        isSaving: state.isSaving,
      );
    }

    return Scaffold(
      backgroundColor: BrandColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WizardStepHeader(step: state.step),
                  const SizedBox(height: 20),
                  WizardCard(child: stepContent),
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

/// Small logo + name row shown at the top of the card in both
/// screenshots — distinct from the full-page BrandHeader used elsewhere.
class _MiniLogoHeader extends StatelessWidget {
  const _MiniLogoHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LogoMark(),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PINCEF TALENTBRIDGE',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            Text('Global Talent Acquisition',
                style: TextStyle(fontSize: 9.5, color: BrandColors.muted)),
          ],
        ),
      ],
    );
  }
}

class _ProfileSummaryStep extends StatelessWidget {
  const _ProfileSummaryStep({
    required this.fullNameController,
    required this.titleController,
    required this.bioController,
    required this.profileImageBytes,
    required this.onPickPhoto,
    required this.locationDisplay,
    required this.onTapLocation,
    required this.onBack,
    required this.onContinue,
  });

  final TextEditingController fullNameController;
  final TextEditingController titleController;
  final TextEditingController bioController;
  final Uint8List? profileImageBytes;
  final VoidCallback onPickPhoto;
  final String locationDisplay;
  final VoidCallback onTapLocation;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  static const _maxBioLength = 1000;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MiniLogoHeader(),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onPickPhoto,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: BrandColors.iconBg,
                backgroundImage: profileImageBytes != null
                    ? MemoryImage(profileImageBytes!)
                    : null,
                child: profileImageBytes == null
                    ? const Icon(Icons.camera_alt_outlined,
                        color: BrandColors.navy)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile Picture',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                  SizedBox(height: 2),
                  Text('Upload a professional photo. JPEG or PNG, max 5MB.',
                      style:
                          TextStyle(fontSize: 11.5, color: BrandColors.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _FieldLabel(
              label: 'Full Name *',
              child: TextFormField(
                controller: fullNameController,
                decoration: authInputDecoration(hint: 'e.g Alex Rivera'),
                style: const TextStyle(color: BrandColors.navy),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FieldLabel(
              label: 'Professional Title *',
              child: TextFormField(
                controller: titleController,
                decoration:
                    authInputDecoration(hint: 'e.g Senior UI/UX Designer'),
                style: const TextStyle(color: BrandColors.navy),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _FieldLabel(
          label: 'Location *',
          child: InkWell(
            onTap: onTapLocation,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: authInputDecoration(
                      hint: 'City, Country or Remote',
                      icon: Icons.location_on_outlined)
                  .copyWith(
                      suffixIcon: const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: BrandColors.navy)),
              child: Text(
                locationDisplay.isEmpty
                    ? 'City, Country or Remote'
                    : locationDisplay,
                style: TextStyle(
                  fontSize: 13.5,
                  color: locationDisplay.isEmpty
                      ? BrandColors.navy.withValues(alpha: 0.4)
                      : BrandColors.navy,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: BrandColors.border),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Bio / About Me',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
            Text('${bioController.text.length} / $_maxBioLength',
                style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: bioController,
          maxLines: 5,
          maxLength: _maxBioLength,
          buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) =>
              null,
          decoration: authInputDecoration(
              hint:
                  'Summarize your professional experience, key skills, and career goals...'),
          style: const TextStyle(color: BrandColors.navy, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const Text(
          'Write a brief, engaging summary highlighting your value proposition. Be authentic and concise.',
          style: TextStyle(fontSize: 11, color: BrandColors.muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        WizardFooterRow(
          onBack: onBack,
          onPrimary: onContinue,
          primaryLabel: 'Continue to Experience',
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.navy)),
          const SizedBox(height: 6),
          child,
        ],
      );
}

class _ExperienceVerificationStep extends StatelessWidget {
  const _ExperienceVerificationStep({
    required this.workExperiences,
    required this.onAddExperience,
    required this.onRemoveExperience,
    required this.educationHistory,
    required this.onAddEducation,
    required this.onRemoveEducation,
    required this.websiteController,
    required this.dribbbleController,
    required this.certifications,
    required this.onUploadCertificate,
    required this.onRemoveCertificate,
    required this.onBack,
    required this.onComplete,
    required this.isSaving,
  });

  final List<WorkExperienceEntry> workExperiences;
  final VoidCallback onAddExperience;
  final ValueChanged<int> onRemoveExperience;
  final List<EducationEntry> educationHistory;
  final VoidCallback onAddEducation;
  final ValueChanged<int> onRemoveEducation;
  final TextEditingController websiteController;
  final TextEditingController dribbbleController;
  final List<CertificationEntry> certifications;
  final VoidCallback onUploadCertificate;
  final ValueChanged<int> onRemoveCertificate;
  final VoidCallback onBack;
  final VoidCallback? onComplete;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MiniLogoHeader(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Build your career timeline',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                  SizedBox(height: 2),
                  Text('Add your most relevant professional experience.',
                      style:
                          TextStyle(fontSize: 11.5, color: BrandColors.muted)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAddExperience,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Experience'),
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
        const SizedBox(height: 14),
        if (workExperiences.isEmpty)
          const Text('No experience added yet.',
              style: TextStyle(fontSize: 12, color: BrandColors.muted))
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < workExperiences.length; i++)
                SizedBox(
                  width: 280,
                  child: _ExperienceCard(
                    entry: workExperiences[i],
                    onRemove: () => onRemoveExperience(i),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        const Divider(color: BrandColors.border),
        const SizedBox(height: 16),
        const Text('Verify your expertise',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: BrandColors.navy)),
        const Text('Provide evidence of your skills and background.',
            style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 520;
          final educationCard = _EducationHistoryCard(
              entries: educationHistory,
              onAdd: onAddEducation,
              onRemove: onRemoveEducation);
          final portfolioCard = _PortfolioCard(
              websiteController: websiteController,
              dribbbleController: dribbbleController);

          return wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: educationCard),
                      const SizedBox(width: 12),
                      Expanded(child: portfolioCard),
                    ],
                  ),
                )
              : Column(children: [
                  educationCard,
                  const SizedBox(height: 12),
                  portfolioCard
                ]);
        }),
        const SizedBox(height: 14),
        _CertificationsDropzone(
          certifications: certifications,
          onUpload: onUploadCertificate,
          onRemove: onRemoveCertificate,
        ),
        const SizedBox(height: 22),
        WizardFooterRow(
          onBack: onBack,
          onPrimary: onComplete ?? () {},
          primaryLabel: isSaving ? 'Saving...' : 'Complete Profile',
          primaryIcon: Icons.check,
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.entry, required this.onRemove});
  final WorkExperienceEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final dateRange = '${entry.startYear} - ${entry.endYear ?? 'Present'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrandColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
                const SizedBox(height: 2),
                Text('${entry.company} • ${entry.employmentType}',
                    style: const TextStyle(
                        fontSize: 11, color: BrandColors.muted)),
                const SizedBox(height: 2),
                Text(dateRange,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: BrandColors.orange,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          InkWell(
              onTap: onRemove,
              child:
                  const Icon(Icons.close, size: 16, color: BrandColors.muted)),
        ],
      ),
    );
  }
}

class _EducationHistoryCard extends StatelessWidget {
  const _EducationHistoryCard(
      {required this.entries, required this.onAdd, required this.onRemove});
  final List<EducationEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.school_outlined, size: 16, color: BrandColors.navy),
                SizedBox(width: 6),
                Text('Education History',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
              ]),
              TextButton(
                  onPressed: onAdd,
                  child: const Text('Add',
                      style:
                          TextStyle(color: BrandColors.orange, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('No education added yet.',
                style: TextStyle(fontSize: 11.5, color: BrandColors.muted))
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entries[i].programme,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: BrandColors.navy)),
                          Text(
                            '${entries[i].school} • ${entries[i].startYear} - ${entries[i].endYear ?? 'Present'}',
                            style: const TextStyle(
                                fontSize: 10.5, color: BrandColors.muted),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                        onTap: () => onRemove(i),
                        child: const Icon(Icons.close,
                            size: 14, color: BrandColors.muted)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard(
      {required this.websiteController, required this.dribbbleController});
  final TextEditingController websiteController;
  final TextEditingController dribbbleController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.language_outlined, size: 16, color: BrandColors.navy),
            SizedBox(width: 6),
            Text('Portfolio',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: websiteController,
            keyboardType: TextInputType.url,
            decoration: authInputDecoration(
                hint: 'Personal Website URL', icon: Icons.public_outlined),
            style: const TextStyle(color: BrandColors.navy, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: dribbbleController,
            keyboardType: TextInputType.url,
            decoration: authInputDecoration(
                hint: 'Dribbble/Behance Profile', icon: Icons.brush_outlined),
            style: const TextStyle(color: BrandColors.navy, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _CertificationsDropzone extends StatelessWidget {
  const _CertificationsDropzone({
    required this.certifications,
    required this.onUpload,
    required this.onRemove,
  });

  final List<CertificationEntry> certifications;
  final VoidCallback onUpload;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: BrandColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.cloud_upload_outlined,
                color: BrandColors.navy, size: 18),
          ),
          const SizedBox(height: 10),
          const Text('Professional Certifications',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy,
                  fontSize: 13.5)),
          const SizedBox(height: 6),
          // FIX: mockup copy said "PDF, JPG, PNG" but the backend's
          // certificate upload route only accepts PDF — copy corrected
          // to match rather than promising formats that would fail.
          const Text(
            'Drag and drop your certificates (PDF) or click to browse.\nMax file size 10MB.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 11, color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onUpload,
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandColors.navy,
              side: const BorderSide(color: BrandColors.border),
            ),
            child: const Text('Select Files'),
          ),
          if (certifications.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < certifications.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.description_outlined,
                      size: 14, color: BrandColors.navy),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(certifications[i].name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                  InkWell(
                      onTap: () => onRemove(i),
                      child: const Icon(Icons.close,
                          size: 14, color: BrandColors.muted)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
