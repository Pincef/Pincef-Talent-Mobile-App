import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/entitlements/module_codes.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../application/application_provider.dart';
import '../../data/models/application_model.dart';
import '../../../candidate_dashboard/presentation/widgets/cv_upload_modal.dart';

/// Shared Job Detail screen — GET /jobs/:jobId (job.service.ts's
/// getJobById, public/unauthenticated) is the same for every viewer; this
/// widget decides what to show/allow based on the logged-in user's role,
/// same pattern app_router.dart already uses to split /jobs itself between
/// JobManagementScreen and BrowseJobsScreen.
///
/// Stateful (not just a ConsumerWidget) specifically to hold `_isEditing` —
/// the recruiter's "Edit Posting" button swaps this same screen into
/// _EditJobForm rather than navigating anywhere else.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final isRecruiter =
        ref.watch(authProvider).user?.role == UserRole.recruiter;

    return jobAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(err.toString()),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(jobDetailProvider(widget.jobId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (job) {
        // Editing only ever applies to the recruiter view — if role
        // somehow flips mid-session, fall back to read-only rather than
        // trust stale local edit-mode state.
        if (_isEditing && isRecruiter) {
          return _EditJobForm(
            job: job,
            onCancel: () => setState(() => _isEditing = false),
            onSaved: () {
              setState(() => _isEditing = false);
              ref.invalidate(jobDetailProvider(widget.jobId));
            },
          );
        }
        return _Body(
          job: job,
          isRecruiter: isRecruiter,
          jobId: widget.jobId,
          onEdit: () => setState(() => _isEditing = true),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.job,
      required this.isRecruiter,
      required this.jobId,
      required this.onEdit});

  final JobDetail job;
  final bool isRecruiter;
  final String jobId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Breadcrumb(title: job.title, isRecruiter: isRecruiter),
              const SizedBox(height: 12),
              _Header(
                  job: job,
                  isRecruiter: isRecruiter,
                  jobId: jobId,
                  isWide: isWide,
                  onEdit: onEdit),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Job Summary',
                child: Text(
                  job.description.isEmpty
                      ? 'No description provided.'
                      : job.description,
                  style: const TextStyle(
                      fontSize: 12.5, color: BrandColors.muted, height: 1.6),
                ),
              ),
              if (job.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Technical Requirements',
                  child: _SkillsGrid(skills: job.requiredSkills),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.title, required this.isRecruiter});
  final String title;
  final bool isRecruiter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/jobs'),
          child: Text(
            isRecruiter ? 'Jobs Management' : 'Browse Jobs',
            style: const TextStyle(
                fontSize: 11.5,
                color: BrandColors.muted,
                fontWeight: FontWeight.w600),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('/',
              style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        ),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11.5,
                color: BrandColors.navy,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.job,
      required this.isRecruiter,
      required this.jobId,
      required this.isWide,
      required this.onEdit});
  final JobDetail job;
  final bool isRecruiter;
  final String jobId;
  final bool isWide;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final actions = isRecruiter
        ? _RecruiterActions(jobId: jobId, onEdit: onEdit)
        : _CandidateActions(job: job, jobId: jobId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(job.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                    _StatusPill(status: job.status),
                  ],
                ),
              ),
              if (isWide) actions,
            ],
          ),
          const SizedBox(height: 4),
          Text(job.companyName,
              style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _MetaItem(icon: Icons.location_on_outlined, label: job.location),
              _MetaItem(
                  icon: Icons.schedule_outlined,
                  label: job.employmentTypeLabel),
              if (job.minYearsOfExperience != null)
                _MetaItem(
                    icon: Icons.timeline_outlined,
                    label: '${job.minYearsOfExperience}+ yrs experience'),
              if (job.educationLevelLabel != null)
                _MetaItem(
                    icon: Icons.school_outlined,
                    label: job.educationLevelLabel!),
              if (job.salaryRangeLabel != null)
                _MetaItem(
                    icon: Icons.payments_outlined,
                    label: job.salaryRangeLabel!),
            ],
          ),
          if (!isWide) ...[const SizedBox(height: 16), actions],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final JobBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      JobBackendStatus.published => (
          const Color(0xFFE8F8EE),
          const Color(0xFF16A34A),
          'ACTIVE'
        ),
      JobBackendStatus.draft => (
          BrandColors.iconBg,
          BrandColors.muted,
          'DRAFT'
        ),
      JobBackendStatus.closed => (
          const Color(0xFFE7E9EF),
          BrandColors.muted,
          'CLOSED'
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BrandColors.muted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
      ],
    );
  }
}

// ============================================================
// Recruiter actions
// ============================================================

class _RecruiterActions extends StatelessWidget {
  const _RecruiterActions({required this.jobId, required this.onEdit});
  final String jobId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit Posting'),
        ),
        ElevatedButton(
          onPressed: () => context.go('/jobs/$jobId/candidates'),
          style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              elevation: 0),
          child: const Text('View Candidates'),
        ),
      ],
    );
  }
}

// ============================================================
// Recruiter edit — same screen, swapped in by _isEditing
// ============================================================

/// Reuses JobDraft and JobManagementRepository.updateJobDraft — the same
/// PATCH /jobs/:jobId post_job_screen.dart's "Save" already uses — rather
/// than inventing a second update path. This form pre-fills from the
/// JobDetail already loaded on this screen instead of navigating to
/// PostJobScreen, which only ever supported creating a new job (no
/// prefill-from-existing-job path existed before this).
class _EditJobForm extends ConsumerStatefulWidget {
  const _EditJobForm(
      {required this.job, required this.onCancel, required this.onSaved});

  final JobDetail job;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditJobForm> createState() => _EditJobFormState();
}

class _EditJobFormState extends ConsumerState<_EditJobForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _minSalary;
  late final TextEditingController _maxSalary;
  late final TextEditingController _currency;
  late final TextEditingController _description;
  late final TextEditingController _minYears;
  late final TextEditingController _skillInput;
  late final TextEditingController _companyOverview;
  late final TextEditingController _responsibilityInput;
  late final TextEditingController _benefitInput;
  late final TextEditingController _deadlineInput;
  late final TextEditingController _assessmentEmailCount;
  late final TextEditingController _interviewEmailCount;

  late String _employmentType;
  late String _workplaceType;
  late String _industry;
  late String _pipelineTier;
  late String _rankingPlanTier;
  late double _rankingLimit;
  String? _educationLevel;
  late bool _requiresManagement;
  late bool _autoRejectNonMatches;
  late bool _aiRanking;
  late bool _aiSummary;
  late List<String> _skills;
  late List<String> _responsibilities;
  late List<String> _benefits;
  DateTime? _applicationDeadline;

  bool _isSaving = false;
  String? _error;

  static const _employmentTypes = {
    'Full-time': 'full_time',
    'Part-time': 'part_time',
    'Contract': 'contract',
    'Internship': 'internship',
  };

  @override
  void initState() {
    super.initState();
    final job = widget.job;
    _title = TextEditingController(text: job.title);
    _location = TextEditingController(text: job.location);
    _minSalary =
        TextEditingController(text: job.minSalary?.toStringAsFixed(0) ?? '');
    _maxSalary =
        TextEditingController(text: job.maxSalary?.toStringAsFixed(0) ?? '');
    _currency = TextEditingController(text: job.currency ?? 'USD');
    _description = TextEditingController(text: job.description);
    _minYears =
        TextEditingController(text: job.minYearsOfExperience?.toString() ?? '');
    _skillInput = TextEditingController();
    _companyOverview = TextEditingController(text: job.companyOverview ?? '');
    _responsibilityInput = TextEditingController();
    _benefitInput = TextEditingController();
    _employmentType = job.employmentType ?? 'full_time';
    _workplaceType =
        const ['on_site', 'hybrid', 'remote'].contains(job.workplaceType)
            ? job.workplaceType!
            : 'on_site';
    _industry = const [
      'Technology',
      'Finance',
      'Healthcare',
      'Education',
      'Retail',
      'Other',
    ].contains(job.industry)
        ? job.industry!
        : 'Technology';
    _educationLevel = job.educationLevel;
    _requiresManagement = job.requiresManagementExperience;
    _autoRejectNonMatches = job.autoRejectNonMatches;
    _aiRanking = job.aiRanking;
    _aiSummary = job.aiSummary;
    _applicationDeadline = job.applicationDeadline;
    _deadlineInput =
        TextEditingController(text: _formatDeadline(_applicationDeadline));
    _assessmentEmailCount =
        TextEditingController(text: job.assessmentEmailCount.toString());
    _interviewEmailCount =
        TextEditingController(text: job.interviewEmailCount.toString());
    _pipelineTier =
        const ['Standard', 'Premium', 'Custom'].contains(job.pipelineTier)
            ? job.pipelineTier
            : 'Standard';
    _rankingPlanTier =
        const ['Standard', 'Premium', 'Custom'].contains(job.rankingPlanTier)
            ? job.rankingPlanTier
            : 'Premium';
    _rankingLimit = job.rankingLimit.toDouble().clamp(1, 30).toDouble();
    _skills = List.of(job.requiredSkills);
    _responsibilities = List.of(job.responsibilities);
    _benefits = List.of(job.benefits);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _minSalary.dispose();
    _maxSalary.dispose();
    _currency.dispose();
    _description.dispose();
    _minYears.dispose();
    _skillInput.dispose();
    _companyOverview.dispose();
    _responsibilityInput.dispose();
    _benefitInput.dispose();
    _deadlineInput.dispose();
    _assessmentEmailCount.dispose();
    _interviewEmailCount.dispose();
    super.dispose();
  }

  void _addSkill() {
    final value = _skillInput.text.trim();
    if (value.isEmpty || _skills.contains(value)) return;
    setState(() {
      _skills.add(value);
      _skillInput.clear();
    });
  }

  Future<void> _editListItem(
      List<String> items, String item, String title) async {
    final index = items.indexOf(item);
    if (index < 0) return;
    final controller = TextEditingController(text: item);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(ctx, controller.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    final updated = value?.trim();
    if (!mounted || updated == null || updated.isEmpty) return;
    setState(() => items[index] = updated);
  }

  void _addToList(TextEditingController controller, List<String> items) {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (!items.contains(value)) items.add(value);
      controller.clear();
    });
  }

  Widget _editableItemsSection({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required String hint,
  }) =>
      _SectionCard(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                InputChip(
                  label: Text(item),
                  onPressed: () =>
                      _editListItem(items, item, 'Edit $title item'),
                  onDeleted: () => setState(() => items.remove(item)),
                ),
            ],
          ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (_) => _addToList(controller, items),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _addToList(controller, items),
              child: const Text('Add'),
            ),
          ]),
        ]),
      );

  Future<void> _pickApplicationDeadline() async {
    final now = DateTime.now();
    final initial = _applicationDeadline ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _applicationDeadline == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay.fromDateTime(_applicationDeadline!.toLocal()),
    );
    if (time == null || !mounted) return;
    setState(() {
      _applicationDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _deadlineInput.text = _formatDeadline(_applicationDeadline);
    });
  }

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return '';
    final local = deadline.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year}, $hour:$minute $period';
  }

  bool get _planAutomationAvailable {
    final user = ref.read(authProvider).user;
    final explicit = user?.capabilities['allowsPlanAutomation'];
    if (explicit is bool) return explicit;
    return user?.hasModule(ModuleCodes.jobsPlanAutomation) ?? false;
  }

  bool _pipelineTierAvailable(String tier) {
    final user = ref.read(authProvider).user;
    if (tier == 'Standard') return true;
    if (tier == 'Premium') {
      final explicit = user?.capabilities['allowsPremiumPipeline'];
      return explicit is bool
          ? explicit
          : user?.hasModule(ModuleCodes.jobPipelinePremium) ?? false;
    }
    final maxCustom =
        (user?.capabilities['maxCustomPipelines'] as num?)?.toInt() ?? 0;
    final hasCustomModule =
        user?.hasModule(ModuleCodes.jobPipelineCustom) == true ||
            user?.hasModule(ModuleCodes.hiringPipeline) == true;
    return hasCustomModule &&
        user?.capabilities['allowsCustomPipelines'] == true &&
        maxCustom > 0;
  }

  // Same bug as the original post_job_screen.dart minYears field (fixed
  // earlier in this conversation): a validator that only checks
  // non-empty lets int.tryParse() fail silently and the field vanish from
  // the payload. Applying the same fix here from the start.
  String? _minYearsValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter minimum years of experience';
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'Enter a whole number (e.g. 3)';
    if (parsed < 0) return 'Years of experience cannot be negative';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_skills.isEmpty) {
      setState(() => _error = 'Add at least one required skill.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final draft = JobDraft(
      id: widget.job.id,
      title: _title.text.trim(),
      description: _description.text.trim(),
      employmentType: _employmentType,
      workplaceType: _workplaceType,
      industry: _industry,
      companyOverview: _companyOverview.text.trim(),
      location: _location.text.trim(),
      minimumSalary: double.tryParse(_minSalary.text.trim()),
      maximumSalary: double.tryParse(_maxSalary.text.trim()),
      currency: _currency.text.trim().isEmpty ? null : _currency.text.trim(),
      requiredSkills: _skills,
      responsibilities: _responsibilities,
      benefits: _benefits,
      minYearsOfExperience: int.tryParse(_minYears.text.trim()),
      educationLevel: _educationLevel,
      requiresManagementExperience: _requiresManagement,
      autoRejectNonMatches: _autoRejectNonMatches,
      applicationDeadline: _applicationDeadline,
      aiRanking: _aiRanking,
      aiSummary: _aiSummary,
      pipelineTier: _pipelineTier,
      rankingPlanTier: _rankingPlanTier,
      rankingLimit: _rankingLimit.round(),
      assessmentEmailCount:
          int.tryParse(_assessmentEmailCount.text.trim()) ?? 15,
      interviewEmailCount: int.tryParse(_interviewEmailCount.text.trim()) ?? 10,
    );

    try {
      await ref
          .read(jobManagementRepositoryProvider)
          .updateJobDraft(widget.job.id, draft);
      if (!mounted) return;
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Edit Job Posting',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: BrandColors.navy)),
                    ),
                    TextButton(
                        onPressed: _isSaving ? null : widget.onCancel,
                        child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Basic Information',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Job Title'),
                      TextFormField(
                        controller: _title,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter a job title'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Employment Type'),
                                DropdownButtonFormField<String>(
                                  initialValue: _employmentType,
                                  items: _employmentTypes.entries
                                      .map((e) => DropdownMenuItem(
                                          value: e.value, child: Text(e.key)))
                                      .toList(),
                                  onChanged: (v) => setState(() =>
                                      _employmentType = v ?? _employmentType),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Location'),
                                TextFormField(controller: _location),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Minimum Salary'),
                                TextFormField(
                                    controller: _minSalary,
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Maximum Salary'),
                                TextFormField(
                                    controller: _maxSalary,
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Currency'),
                                TextFormField(controller: _currency),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _workplaceType,
                            decoration: const InputDecoration(
                                labelText: 'Workplace policy'),
                            items: const {
                              'on_site': 'On-site',
                              'hybrid': 'Hybrid',
                              'remote': 'Remote',
                            }
                                .entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _workplaceType = v ?? _workplaceType),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _industry,
                            decoration:
                                const InputDecoration(labelText: 'Industry'),
                            items: const [
                              'Technology',
                              'Finance',
                              'Healthcare',
                              'Education',
                              'Retail',
                              'Other',
                            ]
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _industry = v ?? _industry),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Company Overview',
                  child: TextFormField(
                    controller: _companyOverview,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Job Summary',
                  child: TextFormField(
                    controller: _description,
                    maxLines: 6,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a job description'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Requirements',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel(
                                    'Minimum Years of Experience'),
                                TextFormField(
                                  controller: _minYears,
                                  keyboardType: TextInputType.number,
                                  validator: _minYearsValidator,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Education Level'),
                                DropdownButtonFormField<String>(
                                  initialValue: _educationLevel,
                                  isExpanded: true,
                                  items: kEducationLevels.entries
                                      .map((e) => DropdownMenuItem(
                                          value: e.value, child: Text(e.key)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _educationLevel = v),
                                  validator: (v) => v == null
                                      ? 'Select a minimum education level'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Requires management experience',
                            style: TextStyle(fontSize: 12.5)),
                        value: _requiresManagement,
                        onChanged: (v) =>
                            setState(() => _requiresManagement = v),
                      ),
                      const SizedBox(height: 6),
                      const _FieldLabel('Required Skills'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final skill in _skills)
                            InputChip(
                              label: Text(skill,
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () => _editListItem(
                                  _skills, skill, 'Edit required skill'),
                              onDeleted: () =>
                                  setState(() => _skills.remove(skill)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skillInput,
                              decoration: const InputDecoration(
                                  hintText: 'Add a skill and press Enter'),
                              onFieldSubmitted: (_) => _addSkill(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                              onPressed: _addSkill, child: const Text('Add')),
                        ],
                      ),
                      if (_skills.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'At least one required skill is needed to keep this job published.',
                            style: TextStyle(
                                fontSize: 10.5, color: BrandColors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _editableItemsSection(
                  title: 'Key Responsibilities',
                  items: _responsibilities,
                  controller: _responsibilityInput,
                  hint: 'Add a responsibility',
                ),
                const SizedBox(height: 16),
                _editableItemsSection(
                  title: 'Benefits',
                  items: _benefits,
                  controller: _benefitInput,
                  hint: 'Add a benefit',
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Hiring Pipeline',
                  child: DropdownButtonFormField<String>(
                    initialValue: _pipelineTier,
                    decoration:
                        const InputDecoration(labelText: 'Pipeline tier'),
                    items: const ['Standard', 'Premium', 'Custom']
                        .map((v) => DropdownMenuItem(
                              value: v,
                              enabled: _pipelineTierAvailable(v) ||
                                  v == _pipelineTier,
                              child: Text(v),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _pipelineTier = v ?? _pipelineTier),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Application Deadline & Settings',
                  child: Column(
                    children: [
                      TextFormField(
                        readOnly: true,
                        controller: _deadlineInput,
                        onTap: _pickApplicationDeadline,
                        decoration: const InputDecoration(
                          labelText: 'Application deadline',
                          hintText: 'Select date and time',
                        ),
                        validator: (_) => (_aiRanking || _aiSummary) &&
                                _applicationDeadline == null
                            ? 'Select a deadline when AI processing is enabled'
                            : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Requires management experience'),
                        value: _requiresManagement,
                        onChanged: (v) =>
                            setState(() => _requiresManagement = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Auto-reject non-matches'),
                        value: _autoRejectNonMatches,
                        onChanged: (v) =>
                            setState(() => _autoRejectNonMatches = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AI candidate ranking'),
                        value: _aiRanking,
                        onChanged: (v) {
                          if (v &&
                              !(ref.read(authProvider).user?.hasModule(
                                      ModuleCodes.aiCandidateMatch) ??
                                  false)) return;
                          setState(() => _aiRanking = v);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('AI resume summary'),
                        value: _aiSummary,
                        onChanged: (v) {
                          if (v &&
                              !(ref.read(authProvider).user?.hasModule(
                                      ModuleCodes.aiCandidateSummary) ??
                                  false)) return;
                          setState(() => _aiSummary = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Plan Automation & Quotas',
                  child: AbsorbPointer(
                    absorbing: !_planAutomationAvailable,
                    child: Opacity(
                      opacity: _planAutomationAvailable ? 1 : .5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_planAutomationAvailable)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Your plan does not include plan automation.',
                                style: TextStyle(
                                    fontSize: 11, color: BrandColors.muted),
                              ),
                            ),
                          DropdownButtonFormField<String>(
                            initialValue: _rankingPlanTier,
                            decoration: const InputDecoration(
                                labelText: 'Candidate ranking plan'),
                            items: const ['Standard', 'Premium', 'Custom']
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _rankingPlanTier = v ?? _rankingPlanTier;
                              _rankingLimit = switch (_rankingPlanTier) {
                                'Standard' => 10,
                                'Premium' => 20,
                                _ => 30,
                              };
                            }),
                          ),
                          Slider(
                            value: _rankingLimit,
                            min: 1,
                            max: 30,
                            divisions: 29,
                            label: '${_rankingLimit.round()} rankings',
                            onChanged: (v) => setState(() => _rankingLimit = v),
                          ),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _assessmentEmailCount,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Assessment emails'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _interviewEmailCount,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Interview emails'),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: BrandColors.muted,
              letterSpacing: 0.4),
        ),
      );
}

// ============================================================
// Candidate actions — apply + CV selection
// ============================================================

class _CandidateActions extends ConsumerWidget {
  const _CandidateActions({required this.job, required this.jobId});
  final JobDetail job;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.status != JobBackendStatus.published) {
      return const Text('Not accepting applications',
          style: TextStyle(fontSize: 11.5, color: BrandColors.muted));
    }

    final applicationsAsync = ref.watch(myApplicationsProvider);
    final applyState = ref.watch(applyProvider);

    return applicationsAsync.when(
      loading: () => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => _ApplyButton(
        isSubmitting: applyState.isSubmitting,
        onTap: () => _handleApply(context, ref),
      ),
      data: (applications) {
        final existing = applications.where((a) => a.jobId == jobId).toList();
        if (existing.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: BrandColors.iconBg,
                borderRadius: BorderRadius.circular(8)),
            child: Text('Applied • ${existing.first.status.label}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
          );
        }
        return _ApplyButton(
          isSubmitting: applyState.isSubmitting,
          onTap: () => _handleApply(context, ref),
        );
      },
    );
  }

  Future<void> _handleApply(BuildContext context, WidgetRef ref) async {
    List<CvFileOption> cvFiles;
    try {
      cvFiles = await ref.read(myCvFilesProvider.future);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.error(context, 'Could not load your CVs: $e');
      return;
    }
    if (!context.mounted) return;

    if (cvFiles.isEmpty) {
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upload a CV first'),
          content: const Text(
              'You need at least one CV on your profile before applying.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Upload CV')),
          ],
        ),
      );
      if (shouldUpload == true && context.mounted) {
        showCandidateCvUploadModal(context, ref);
      }
      return;
    }

    String? cvPublicId;
    if (cvFiles.length > 1) {
      cvPublicId = await _showCvPicker(context, cvFiles);
      if (cvPublicId == null) return; // cancelled
    } else {
      cvPublicId = cvFiles.first.publicId;
    }

    final success = await ref
        .read(applyProvider.notifier)
        .submit(jobId, cvPublicId: cvPublicId);
    if (!context.mounted) return;

    if (success) {
      ref.invalidate(
          myApplicationsProvider); // so "Applied" reflects immediately
      final result = ref.read(applyProvider).result!;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ApplicationSubmittedDialog(
            application: result, jobTitle: job.title),
      );
      if (context.mounted) AppToast.success(context, 'Application submitted.');
    } else {
      final error =
          ref.read(applyProvider).error ?? 'Could not submit your application.';
      AppToast.error(context, error);
    }
  }

  Future<String?> _showCvPicker(
      BuildContext context, List<CvFileOption> cvFiles) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Which CV should we use?',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              const Text(
                  'You have more than one CV on file for this application.',
                  style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
              const SizedBox(height: 8),
              for (final cv in cvFiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined,
                      color: BrandColors.navy),
                  title: Text(cv.originalName,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Uploaded ${_formatDate(cv.uploadedAt)}',
                      style: const TextStyle(
                          fontSize: 10.5, color: BrandColors.muted)),
                  onTap: () => Navigator.pop(sheetContext, cv.publicId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.isSubmitting, required this.onTap});
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: BrandColors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: isSubmitting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Text('Apply Now',
              style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ============================================================
// Post-apply confirmation
// ============================================================

class _ApplicationSubmittedDialog extends StatelessWidget {
  const _ApplicationSubmittedDialog(
      {required this.application, required this.jobTitle});
  final ApplicationSummary application;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F8EE), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Application Submitted',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              Text('Thank you for applying to $jobTitle.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: BrandColors.muted)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: BrandColors.iconBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Reference: ${application.referenceNumber}',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.orange)),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: BrandColors.iconBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.checklist_outlined,
                            size: 14, color: BrandColors.navy),
                        SizedBox(width: 6),
                        Text('What to expect next',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.navy)),
                      ],
                    ),
                    SizedBox(height: 10),
                    _ExpectationStep(
                      title: 'Application Review',
                      description:
                          'Our recruiting team will review your application and profile.',
                      active: true,
                    ),
                    _ExpectationStep(
                      title: 'Initial Screening',
                      description:
                          'If selected, you may be invited to an introductory call.',
                      active: false,
                    ),
                    _ExpectationStep(
                      title: 'Interview',
                      description:
                          'A deeper conversation with the hiring team.',
                      active: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/jobs');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.work_outline, size: 16),
                  label: const Text('Return to Jobs'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpectationStep extends StatelessWidget {
  const _ExpectationStep(
      {required this.title, required this.description, required this.active});
  final String title;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? BrandColors.orange : BrandColors.border),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
                Text(description,
                    style: const TextStyle(
                        fontSize: 10.5, color: BrandColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Technical requirements
// ============================================================

/// job.model.ts's requiredSkills is just string[] — there's no per-skill
/// description field, so unlike the mockup these cards show the skill name
/// only rather than fabricated blurbs under each one.
class _SkillsGrid extends StatelessWidget {
  const _SkillsGrid({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: skills
          .map((skill) => Container(
                constraints: const BoxConstraints(minWidth: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: BrandColors.iconBg.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 16, color: BrandColors.navy),
                    const SizedBox(width: 8),
                    Text(skill,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: BrandColors.navy)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
