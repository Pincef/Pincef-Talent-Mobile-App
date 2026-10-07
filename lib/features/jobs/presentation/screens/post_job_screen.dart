import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/application/location_provider.dart';
import 'package:talentbridge/core/data/models/location_models.dart';
import 'package:talentbridge/core/entitlements/module_codes.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/jobs/application/job_management_provider.dart';
import 'package:talentbridge/features/jobs/data/models/job_management_model.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _minimum = TextEditingController();
  final _maximum = TextEditingController();
  final _companyOverview = TextEditingController();
  final _overview = TextEditingController();
  final _responsibility = TextEditingController();
  final _requirement = TextEditingController();
  final _applicationInstructions = TextEditingController();
  final _streetAddress = TextEditingController();
  final _deadlineController = TextEditingController();
  final _minYears = TextEditingController();
  final _customBenefit = TextEditingController();
  final _assessmentEmailCount = TextEditingController(text: '15');
  final _interviewEmailCount = TextEditingController(text: '10');

  DateTime? _deadline;
  String _employment = 'Full-time';
  String _workplace = 'On-site';
  String _currency = 'USD';
  String _industry = 'Technology';
  String _pipelineTier = 'Standard';
  String _planTier = 'Premium';
  String? _pendingAction;
  double _rankingLimit = 20;
  String? _countryCode;
  String? _countryName;
  String? _stateCode;
  String? _stateName;
  String? _city;
  bool _health = true;
  bool _equity = true;
  bool _learning = false;
  bool _wellness = false;
  bool _autoReject = false;
  bool _aiRanking = false;
  bool _aiSummary = false;
  String? _educationLevel;
  bool _requiresManagement = false;
  final List<String> _responsibilities = [];
  final List<String> _requirements = [];
  final List<String> _customBenefits = [];

  static const _employmentTypeValues = {
    'Full-time': 'full_time',
    'Part-time': 'part_time',
    'Contract': 'contract',
    'Internship': 'internship',
  };
  static const _workplaceTypeValues = {
    'On-site': 'on_site',
    'Hybrid': 'hybrid',
    'Remote': 'remote',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(locationsProvider.notifier).loadCountries(),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _minimum,
      _maximum,
      _companyOverview,
      _overview,
      _responsibility,
      _requirement,
      _applicationInstructions,
      _streetAddress,
      _deadlineController,
      _minYears,
      _customBenefit,
      _assessmentEmailCount,
      _interviewEmailCount,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    final saving = ref.watch(postJobProvider).isSaving;
    final usage = ref.watch(jobManagementProvider);
    final monthlyLimit =
        (ref.read(authProvider).user?.limits['jobsPerMonth'] as num?)?.toInt();
    final monthlyPublished = usage.summary?.monthlyPublishedCount;
    final atMonthlyLimit = monthlyLimit != null &&
        monthlyPublished != null &&
        monthlyPublished >= monthlyLimit;
    return Container(
      color: const Color(0xFFF5F7FB),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(constraints.maxWidth > 800 ? 28 : 16, 22,
              constraints.maxWidth > 800 ? 28 : 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (monthlyLimit != null) ...[
                        _monthlyJobsNotice(
                          used: monthlyPublished,
                          limit: monthlyLimit,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _pageHeader(
                        saving,
                        canPublish: monthlyLimit == null ||
                            (monthlyPublished != null && !atMonthlyLimit),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(builder: (context, box) {
                        final wide = box.maxWidth >= 850;
                        final left = Column(children: [
                          _foundationCard(),
                          const SizedBox(height: 18),
                          _requirementsCard(),
                        ]);
                        final right = Column(children: [
                          _remunerationCard(),
                          const SizedBox(height: 18),
                          _applicationFlowCard(),
                          const SizedBox(height: 18),
                          _planAutomationCard(),
                          const SizedBox(height: 18),
                          _deadlineCard(),
                          const SizedBox(height: 18),
                          _settingsCard(),
                        ]);
                        if (!wide) {
                          return Column(children: [
                            _foundationCard(),
                            const SizedBox(height: 14),
                            _remunerationCard(),
                            const SizedBox(height: 14),
                            _requirementsCard(),
                            const SizedBox(height: 14),
                            _applicationFlowCard(),
                            const SizedBox(height: 14),
                            _planAutomationCard(),
                            const SizedBox(height: 14),
                            _deadlineCard(),
                            const SizedBox(height: 14),
                            _settingsCard(),
                          ]);
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 13, child: left),
                            const SizedBox(width: 20),
                            Expanded(flex: 9, child: right),
                          ],
                        );
                      }),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthlyJobsNotice({required int? used, required int limit}) {
    final blocked = used != null && used >= limit;
    final message = used == null
        ? 'Checking this month’s job posting usage…'
        : blocked
            ? 'You’ve used all $limit job postings included in your plan this month. Upgrade your subscription to post more.'
            : '$used of $limit job postings used this month.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: blocked ? const Color(0xFFFFF1F0) : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: blocked
              ? const Color(0xFFF3C7C3)
              : const Color(0xFFF2D8AF),
        ),
      ),
      child: Row(children: [
        Icon(blocked ? Icons.lock_outline : Icons.info_outline,
            size: 18,
            color: blocked ? const Color(0xFFB42318) : BrandColors.orange),
        const SizedBox(width: 9),
        Expanded(
          child: Text(message,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        if (blocked)
          TextButton(
            onPressed: () => context.go('/payments'),
            child: const Text('View plans'),
          ),
      ]),
    );
  }

  Widget _pageHeader(bool saving, {required bool canPublish}) => LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 740;
          final titleBlock =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE7),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('JOB CREATION WIZARD',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.orange,
                        letterSpacing: .5))),
            const SizedBox(height: 7),
            const Text('Post New Job',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const SizedBox(height: 2),
            const Text(
                'Define the future of your organization by attracting top-tier global talent.',
                style: TextStyle(fontSize: 14, color: BrandColors.muted)),
          ]);
          final actions = Wrap(
            spacing: 9,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _showEmailTemplates,
                icon: const Icon(Icons.mail_outline, size: 15),
                label: const Text('View Email Templates'),
                style: _draftButtonStyle,
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : _saveDraft,
                icon: saving && _pendingAction == 'draft'
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 15),
                label: Text(saving && _pendingAction == 'draft'
                    ? 'Saving...'
                    : 'Save as Draft'),
                style: _draftButtonStyle,
              ),
              FilledButton.icon(
                onPressed: saving || !canPublish ? null : _publishJob,
                icon: saving && _pendingAction == 'publish'
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt, size: 15),
                label: Text(saving && _pendingAction == 'publish'
                    ? 'Publishing...'
                    : 'Publish Job'),
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 14), actions],
            );
          }
          return Row(children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            Flexible(child: actions),
          ]);
        },
      );

  Widget _foundationCard() => _panel(
      icon: Icons.edit_note_outlined,
      iconColor: const Color(0xFFFFE8DF),
      title: 'Job Foundation',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('JOB TITLE'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _title,
          validator: _required('Enter a job title'),
          decoration: _input('Senior Full Stack Engineer (Remote)'),
        ),
        const SizedBox(height: 13),
        _label('LOCATION'),
        const SizedBox(height: 6),
        _locationFields(),
        const SizedBox(height: 13),
        LayoutBuilder(
            builder: (context, box) => box.maxWidth > 430
                ? Row(children: [
                    Expanded(
                        child: _dropdownField(
                            'INDUSTRY / SECTOR',
                            _industry,
                            const [
                              'Technology',
                              'Finance',
                              'Healthcare',
                              'Education',
                              'Retail',
                              'Other'
                            ],
                            (v) => setState(() => _industry = v!))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _dropdownField(
                            'JOB LOCATION / POLICY',
                            _workplace,
                            const ['On-site', 'Hybrid', 'Remote'],
                            (v) => setState(() => _workplace = v!)))
                  ])
                : Column(children: [
                    _dropdownField(
                        'INDUSTRY / SECTOR',
                        _industry,
                        const [
                          'Technology',
                          'Finance',
                          'Healthcare',
                          'Education',
                          'Retail',
                          'Other'
                        ],
                        (v) => setState(() => _industry = v!)),
                    const SizedBox(height: 12),
                    _dropdownField(
                        'JOB LOCATION / POLICY',
                        _workplace,
                        const ['On-site', 'Hybrid', 'Remote'],
                        (v) => setState(() => _workplace = v!))
                  ])),
        const SizedBox(height: 13),
        _label('COMPANY OVERVIEW'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _companyOverview,
          maxLines: 3,
          decoration: _input(
              'Tell candidates about your company\'s mission and culture...'),
        ),
        const SizedBox(height: 13),
        Row(children: [
          _label('JOB DESCRIPTION'),
          const Spacer(),
          Tooltip(
            message: _aiJobDescriptionAvailable
                ? 'AI job description generation is not connected yet.'
                : 'Your current plan doesn\'t include AI job description generation. Upgrade your plan to unlock it.',
            child: Opacity(
              opacity: _aiJobDescriptionAvailable ? 1 : .45,
              child: TextButton.icon(
                onPressed: _aiJobDescriptionAvailable
                    ? () => AppToast.info(context,
                        'AI job description generation is coming soon.')
                    : null,
                icon: const Icon(Icons.auto_awesome, size: 12),
                label: const Text('Generate with AI'),
                style: TextButton.styleFrom(
                  foregroundColor: BrandColors.orange,
                  disabledForegroundColor: BrandColors.muted,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                      fontSize: 10, decoration: TextDecoration.underline),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        TextFormField(
          controller: _overview,
          validator: _required('Add a job description'),
          maxLines: 5,
          decoration:
              _input('Briefly describe the impact and scope of this role...'),
        ),
      ]));

  Widget _remunerationCard() => _panel(
      icon: Icons.payments_outlined,
      iconColor: const Color(0xFFFFE8DF),
      title: 'Remuneration',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('CURRENCY'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          isDense: true,
          items: const ['USD', 'NGN', 'GBP', 'EUR', 'CAD']
              .map((currency) =>
                  DropdownMenuItem(value: currency, child: Text(currency)))
              .toList(),
          onChanged: (currency) =>
              setState(() => _currency = currency ?? _currency),
          decoration: _input('Select currency'),
        ),
        const SizedBox(height: 13),
        _label('SALARY RANGE (${_currency.toUpperCase()})'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: TextFormField(
                  controller: _minimum,
                  keyboardType: TextInputType.number,
                  decoration: _input('Min'))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('to',
                  style: TextStyle(fontSize: 10, color: BrandColors.muted))),
          Expanded(
              child: TextFormField(
                  controller: _maximum,
                  keyboardType: TextInputType.number,
                  decoration: _input('Max')))
        ]),
        const SizedBox(height: 12),
        _label('BENEFITS PACKAGE'),
        const SizedBox(height: 7),
        LayoutBuilder(builder: (context, box) {
          final width = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
                width: width,
                child: _benefit('Health Ins.', _health,
                    (v) => setState(() => _health = v))),
            SizedBox(
                width: width,
                child: _benefit('Equity/RSUs', _equity,
                    (v) => setState(() => _equity = v))),
            SizedBox(
                width: width,
                child: _benefit('Learning Stipend', _learning,
                    (v) => setState(() => _learning = v))),
            SizedBox(
                width: width,
                child: _benefit('Wellness', _wellness,
                    (v) => setState(() => _wellness = v))),
            ..._customBenefits.map((benefit) =>
                SizedBox(width: width, child: _customBenefitChip(benefit))),
          ]);
        }),
        const SizedBox(height: 10),
        TextFormField(
          controller: _customBenefit,
          onFieldSubmitted: (_) => _addCustomBenefit(),
          decoration: _input('Add another benefit or package').copyWith(
            suffixIcon: IconButton(
              tooltip: 'Add benefit',
              onPressed: _addCustomBenefit,
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: BrandColors.orange),
            ),
          ),
        ),
      ]));

  Widget _requirementsCard() => _panel(
      icon: Icons.fact_check_outlined,
      iconColor: const Color(0xFFDFF6ED),
      iconForeground: const Color(0xFF0AA87D),
      title: 'Requirements',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _listEditor('KEY RESPONSIBILITIES', _responsibility, _responsibilities,
            'Add Point'),
        const SizedBox(height: 19),
        _listEditor(
            'TECHNICAL REQUIREMENTS', _requirement, _requirements, 'Add Point'),
        const SizedBox(height: 16),
        _minYearsField(),
        const SizedBox(height: 14),
        _educationLevelField(),
      ]));

  Widget _minYearsField() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('MINIMUM YEARS OF EXPERIENCE'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _minYears,
          keyboardType: TextInputType.number,
          validator: _minYearsValidator,
          decoration: _input('e.g. 3'),
        ),
      ]);

  Widget _educationLevelField() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('MINIMUM EDUCATION LEVEL'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _educationLevel,
          isExpanded: true,
          items: kEducationLevels.entries
              .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
              .toList(),
          onChanged: (v) => setState(() => _educationLevel = v),
          validator: (v) =>
              v == null ? 'Select a minimum education level' : null,
          decoration: _input('Select level'),
        ),
      ]);

  Widget _applicationFlowCard() => _panel(
      icon: Icons.account_tree_outlined,
      iconColor: const Color(0xFFEAE8FF),
      iconForeground: const Color(0xFF7771B9),
      title: 'Application Flow',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('SELECT HIRING PIPELINE'),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/hiring-pipelines'),
            icon: const Icon(Icons.account_tree_outlined, size: 15),
            label: const Text('View Pipelines'),
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _pipelineTierChoices(),
      ]));

  bool get _premiumPipelineAvailable {
    final user = ref.read(authProvider).user;
    final explicit = user?.capabilities['allowsPremiumPipeline'];
    if (explicit is bool) return explicit;
    return user?.hasModule(ModuleCodes.jobPipelinePremium) ?? false;
  }

  bool get _customPipelineAvailable {
    final user = ref.read(authProvider).user;
    final maxCustom =
        (user?.capabilities['maxCustomPipelines'] as num?)?.toInt() ?? 0;
    final hasCustomModule =
        user?.hasModule(ModuleCodes.jobPipelineCustom) == true ||
            user?.hasModule(ModuleCodes.hiringPipeline) == true;
    return hasCustomModule &&
        user?.capabilities['allowsCustomPipelines'] == true &&
        maxCustom > 0;
  }

  bool get _planAutomationAvailable {
    final user = ref.read(authProvider).user;
    final explicit = user?.capabilities['allowsPlanAutomation'];
    if (explicit is bool) return explicit;
    return user?.hasModule(ModuleCodes.jobsPlanAutomation) ?? false;
  }

  bool get _aiJobDescriptionAvailable {
    final user = ref.read(authProvider).user;
    final explicit = user?.capabilities['allowsAiJobDescriptionGeneration'];
    if (explicit is bool) return explicit;
    return user?.hasModule(ModuleCodes.aiJobDescriptionGeneration) ?? false;
  }

  Widget _pipelineTierChoices() => Row(
        children: [
          _pipelineTierChoice('Standard', enabled: true),
          const SizedBox(width: 7),
          _pipelineTierChoice('Premium', enabled: _premiumPipelineAvailable),
          const SizedBox(width: 7),
          _pipelineTierChoice(
            'Custom',
            enabled: _customPipelineAvailable,
            opensModal: true,
          ),
        ],
      );

  Widget _pipelineTierChoice(String tier,
          {required bool enabled, bool opensModal = false}) =>
      Expanded(
        child: Tooltip(
          message: enabled
              ? ''
              : tier == 'Premium'
                  ? 'Your current plan doesn\'t include the Premium hiring pipeline. Upgrade your plan to unlock it.'
                  : 'Your current plan doesn\'t include custom hiring pipelines. Upgrade your plan to unlock them.',
          child: Opacity(
            opacity: enabled ? 1 : .42,
            child: InkWell(
              onTap: enabled || opensModal
                  ? () {
                      if (opensModal) {
                        _showPipelinePicker();
                      } else {
                        setState(() => _pipelineTier = tier);
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: _pipelineTier == tier
                      ? const Color(0xFFFFF0DE)
                      : const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _pipelineTier == tier
                        ? const Color(0xFFFFC88F)
                        : const Color(0xFFE5EBF3),
                    width: _pipelineTier == tier ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!enabled) ...[
                      const Icon(Icons.lock_outline,
                          size: 11, color: BrandColors.muted),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        tier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _pipelineTier == tier && enabled
                              ? BrandColors.orange
                              : BrandColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _showPipelinePicker() async {
    final selected = await showDialog<String>(
      context: context,
      barrierColor: const Color(0xD90B142A),
      builder: (dialogContext) => _HiringPipelinePickerDialog(
        premiumAvailable: _premiumPipelineAvailable,
        customAvailable: _customPipelineAvailable,
        initialSelection: _pipelineTier,
        accountName: ref.read(authProvider).user?.fullName ?? 'Recruiter',
      ),
    );
    if (selected != null && mounted) {
      setState(() => _pipelineTier = selected);
      _showToast('$selected pipeline selected.', isError: false);
    }
  }

  Widget _planAutomationCard() {
    final available = _planAutomationAvailable;
    return Tooltip(
      message: available
          ? ''
          : 'Plan Automation & Quotas isn\'t included in your current plan. Upgrade to access it.',
      child: Opacity(
        opacity: available ? 1 : .48,
        child: AbsorbPointer(
          absorbing: !available,
          child: _panel(
            icon: Icons.bar_chart_outlined,
            iconColor: const Color(0xFFFFF1E8),
            title: 'Plan Automation & Quotas',
            titleTrailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: available
                    ? const Color(0xFFFFF0D9)
                    : const Color(0xFFE5EAF0),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(available ? 'PREMIUM ACTIVE' : 'PREMIUM REQUIRED',
                  style: TextStyle(
                      color: available ? BrandColors.orange : BrandColors.muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w800)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!available) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_outline,
                        size: 15, color: BrandColors.muted),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Plan automation and quotas are available on eligible plans.',
                        style: TextStyle(
                            color: BrandColors.muted,
                            fontSize: 10,
                            height: 1.3),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(child: _label('CANDIDATE RANKINGS BY PLAN')),
                Text('${_rankingLimit.round()} Rankings',
                    style: const TextStyle(
                        color: BrandColors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              _choiceTiles(const ['Standard', 'Premium', 'Custom'], _planTier,
                  (value) {
                setState(() {
                  _planTier = value;
                  _rankingLimit = switch (value) {
                    'Standard' => 10,
                    'Premium' => 20,
                    _ => 30,
                  };
                });
              }),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: BrandColors.orange,
                  inactiveTrackColor: const Color(0xFFE3EAF4),
                  thumbColor: BrandColors.orange,
                  overlayColor: BrandColors.orange.withValues(alpha: .12),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _rankingLimit,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (value) => setState(() => _rankingLimit = value),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1 Min',
                      style: TextStyle(fontSize: 8, color: BrandColors.muted)),
                  Text('10 (Std)',
                      style: TextStyle(fontSize: 8, color: BrandColors.muted)),
                  Text('20 (Prem)',
                      style: TextStyle(fontSize: 8, color: BrandColors.orange)),
                  Text('30 (Custom)',
                      style: TextStyle(fontSize: 8, color: BrandColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              _quotaRow(
                'Automated Assessment Emails',
                'Allowed: Prem 1–20 | Custom 1–30',
                _assessmentEmailCount,
              ),
              const SizedBox(height: 10),
              _quotaRow(
                'Interview Invitation Emails',
                'Targeting top 10 prepared candidates',
                _interviewEmailCount,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showEmailTemplates,
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Preview & Edit Email Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandColors.orange,
                    side: const BorderSide(color: Color(0xFFFFD6BB)),
                    backgroundColor: const Color(0xFFFFF8F2),
                    textStyle: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _deadlineCard() => _panel(
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFFFFE8DF),
      title: 'Application Deadline',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('DEADLINE DATE & TIME'),
        const SizedBox(height: 6),
        TextFormField(
            controller: _deadlineController,
            readOnly: true,
            onTap: _pickDeadline,
            validator: _required('Select an application deadline'),
            decoration: _input('mm/dd/yyyy, --:--').copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined,
                    size: 16, color: BrandColors.muted))),
        const SizedBox(height: 8),
        const Text(
            'This job posting will automatically close and stop accepting applications once this timeline elapses.',
            style: TextStyle(
                fontSize: 8.5, color: BrandColors.muted, height: 1.35)),
      ]));

  Widget _settingsCard() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: BrandColors.navy,
          border: Border.all(color: const Color(0xFF28345E)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Post Settings',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF202A50), height: 1),
        const SizedBox(height: 8),
        _setting('Promote on LinkedIn', true),
        _setting('Auto-reject non-matches', _autoReject,
            changed: (v) => setState(() => _autoReject = v)),
        _setting(
          'AI candidate ranking',
          _aiRanking,
          changed: (v) => setState(() => _aiRanking = v),
          enabled: ref.read(authProvider).user?.hasModule(
                  ModuleCodes.aiCandidateMatch) ??
              false,
        ),
        _setting(
          'AI resume summary',
          _aiSummary,
          changed: (v) => setState(() => _aiSummary = v),
          enabled: ref.read(authProvider).user?.hasModule(
                  ModuleCodes.aiCandidateSummary) ??
              false,
        ),
        _setting('Requires management experience', _requiresManagement,
            changed: (v) => setState(() => _requiresManagement = v)),
      ]));

  Widget _locationFields() {
    final locations = ref.watch(locationsProvider);
    final country = _locationSelect(
        _safeValue(_countryCode, locations.countries.map((x) => x.isoCode)),
        locations.isLoadingCountries ? 'Loading countries...' : 'Country',
        locations.countries
            .map((x) =>
                DropdownMenuItem(value: x.isoCode, child: Text(x.displayLabel)))
            .toList(),
        locations.isLoadingCountries
            ? null
            : (v) => _onCountryChanged(v, locations.countries));
    final state = _locationSelect(
        _safeValue(_stateCode, locations.states.map((x) => x.isoCode)),
        _countryCode == null
            ? 'State'
            : locations.isLoadingStates
                ? 'Loading states...'
                : 'State',
        locations.states
            .map((x) => DropdownMenuItem(value: x.isoCode, child: Text(x.name)))
            .toList(),
        _countryCode == null || locations.isLoadingStates
            ? null
            : (v) => _onStateChanged(v, locations.states));
    final city = _locationSelect(
        _safeValue(_city, locations.cities.map((x) => x.name)),
        _stateCode == null
            ? 'City'
            : locations.isLoadingCities
                ? 'Loading cities...'
                : 'City',
        locations.cities
            .map((x) => DropdownMenuItem(value: x.name, child: Text(x.name)))
            .toList(),
        _stateCode == null || locations.isLoadingCities
            ? null
            : _onCityChanged);
    return LayoutBuilder(
        builder: (context, box) => box.maxWidth > 430
            ? Row(children: [
                Expanded(child: country),
                const SizedBox(width: 8),
                Expanded(child: state),
                const SizedBox(width: 8),
                Expanded(child: city)
              ])
            : Column(children: [
                country,
                const SizedBox(height: 8),
                state,
                const SizedBox(height: 8),
                city
              ]));
  }

  Widget _listEditor(String label, TextEditingController controller,
          List<String> items, String action) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _label(label),
          const Spacer(),
          TextButton.icon(
              onPressed: () => _promptAddItem(controller, items),
              icon: const Icon(Icons.add_circle_outline, size: 14),
              label: Text(action),
              style: TextButton.styleFrom(
                  foregroundColor: BrandColors.orange,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700)))
        ]),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              label == 'KEY RESPONSIBILITIES'
                  ? 'Add the main responsibilities for this role.'
                  : 'Add the skills and experience candidates should have.',
              style: const TextStyle(
                  fontSize: 10, color: BrandColors.muted, height: 1.4),
            ),
          ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE4EAF3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.navy),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => items.remove(item)),
                    child: const Icon(
                      Icons.delete_outline,
                      color: BrandColors.orange,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]);

  Widget _panel(
          {required IconData icon,
          required Color iconColor,
          Color? iconForeground,
          required String title,
          Widget? titleTrailing,
          required Widget child}) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF2D9CE)),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080B1739),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon,
                      size: 20, color: iconForeground ?? BrandColors.orange)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
              ),
              if (titleTrailing != null) titleTrailing,
            ]),
            const SizedBox(height: 18),
            child
          ]));
  Widget _dropdownField(String label, String value, List<String> values,
          ValueChanged<String?> changed) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            items: values
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: changed,
            decoration: _input(''))
      ]);
  Widget _locationSelect(
          String? value,
          String hint,
          List<DropdownMenuItem<String>> items,
          ValueChanged<String?>? changed) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: items,
          onChanged: changed,
          decoration: _input(hint));
  Widget _benefit(String label, bool selected, ValueChanged<bool> onChanged) =>
      InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(11),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4EAF3)),
                  borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                Icon(selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: selected ? BrandColors.orange : BrandColors.muted,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 10, color: BrandColors.navy),
                        overflow: TextOverflow.ellipsis))
              ])));
  Widget _customBenefitChip(String benefit) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF6F1),
          border: Border.all(color: const Color(0xFFE4EAF3)),
          borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        Expanded(
            child: Text(benefit,
                style: const TextStyle(fontSize: 10, color: BrandColors.navy),
                overflow: TextOverflow.ellipsis)),
        InkWell(
            onTap: () => setState(() => _customBenefits.remove(benefit)),
            child: const Icon(Icons.close, size: 13, color: BrandColors.orange))
      ]));
  Widget _setting(String label, bool value,
          {ValueChanged<bool>? changed, bool enabled = true}) =>
      SizedBox(
          height: 34,
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: .72)))),
            if (!enabled)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.lock_outline,
                    size: 13, color: BrandColors.muted),
              ),
            SizedBox(
                height: 15,
                child: FittedBox(
                    child: Switch(
                        value: enabled && value,
                        onChanged: enabled ? changed : null,
                        activeThumbColor: Colors.white,
                        activeTrackColor: BrandColors.orange)))
          ]));
  Widget _choiceTiles(
    List<String> choices,
    String selected,
    ValueChanged<String> onSelected,
  ) =>
      Row(
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSelected(choices[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == choices[i]
                        ? const Color(0xFFFFF0DE)
                        : const Color(0xFFF3F6FA),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected == choices[i]
                          ? const Color(0xFFFFC88F)
                          : const Color(0xFFE5EBF3),
                      width: selected == choices[i] ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    choices[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected == choices[i]
                          ? BrandColors.orange
                          : BrandColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );

  Widget _quotaRow(
    String title,
    String subtitle,
    TextEditingController controller,
  ) =>
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFE),
          border: Border.all(color: const Color(0xFFE5EBF3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: BrandColors.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 8, height: 1.25)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: _input('0').copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              ),
              style: const TextStyle(fontSize: 10, color: BrandColors.navy),
            ),
          ),
          const SizedBox(width: 6),
          const Text('emails',
              style: TextStyle(fontSize: 9, color: BrandColors.muted)),
        ]),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          color: BrandColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: .2));
  InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF9AA2B1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3EAF4))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.orange, width: 1.2)));
  String? _safeValue(String? value, Iterable<String> values) =>
      value != null && values.contains(value) ? value : null;
  String? Function(String?) _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;
  // Unlike _required, this also checks the text is actually a valid
  // non-negative integer — int.tryParse() returns null on bad input, and
  // that null was previously being dropped from the payload silently
  // (JobDraft.toJson() only sends the key when it's non-null), so the job
  // would save without minYearsOfExperience even though the field looked
  // "filled" and passed the old emptiness-only validator.
  String? _minYearsValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter minimum years of experience';
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'Enter a whole number (e.g. 3)';
    if (parsed < 0) return 'Years of experience cannot be negative';
    return null;
  }

  String get _jobLocation => [
        _streetAddress.text.trim(),
        _city,
        _stateName,
        _countryName
      ].where((value) => value != null && value.trim().isNotEmpty).join(', ');
  void _onCountryChanged(String? code, List<CountryEntry> countries) {
    if (code == null) return;
    final country = countries.firstWhere((x) => x.isoCode == code);
    setState(() {
      _countryCode = country.isoCode;
      _countryName = country.name;
      _stateCode = null;
      _stateName = null;
      _city = null;
    });
    ref.read(locationsProvider.notifier).loadStates(code);
  }

  void _onStateChanged(String? code, List<StateEntry> states) {
    if (code == null) return;
    final state = states.firstWhere((x) => x.isoCode == code);
    setState(() {
      _stateCode = state.isoCode;
      _stateName = state.name;
      _city = null;
    });
    ref.read(locationsProvider.notifier).loadCities(_countryCode!, code);
  }

  void _onCityChanged(String? value) {
    if (value != null) setState(() => _city = value);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate:
          _deadline != null && _deadline!.isAfter(now) ? _deadline! : now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _deadline != null
          ? TimeOfDay.fromDateTime(_deadline!)
          : const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null || !mounted) return;
    setState(() {
      _deadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _deadlineController.text = _formatDeadline(_deadline!);
    });
  }

  String _formatDeadline(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${two(d.month)}/${two(d.day)}/${d.year}, '
        '${two(hour12)}:${two(d.minute)} $period';
  }

  void _addItem(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      setState(() {
        target.add(value);
        controller.clear();
      });
    }
  }

  Future<void> _promptAddItem(
      TextEditingController controller, List<String> target) async {
    controller.clear();
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(target == _responsibilities
            ? 'Add responsibility'
            : 'Add technical requirement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: _input(target == _responsibilities
              ? 'Describe a key responsibility...'
              : 'Describe a technical requirement...'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add Point')),
        ],
      ),
    );
    if (shouldAdd == true) _addItem(controller, target);
  }

  Future<void> _showEmailTemplates() => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Email Templates'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.mark_email_read_outlined),
                title: Text('Application received'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.assignment_outlined),
                title: Text('Assessment invitation'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event_outlined),
                title: Text('Interview invitation'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
          ],
        ),
      );

  void _addCustomBenefit() {
    final value = _customBenefit.text.trim();
    if (value.isEmpty || _customBenefits.contains(value)) return;
    setState(() {
      _customBenefits.add(value);
      _customBenefit.clear();
    });
  }

  void _showError(String fallback) {
    if (!mounted) return;
    final rawMessage = ref.read(postJobProvider).error;
    final message = rawMessage
            ?.replaceFirst(RegExp(r'^Exception:\s*'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'^\w+Exception:\s*'), '') ??
        '';
    _showToast(message.isEmpty ? fallback : message, isError: true);
  }

  void _showToast(String message, {required bool isError}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  /// Builds the full [JobDraft] from the current form state and persists
  /// it in a single call. Now that the form is one screen instead of a
  /// multi-step wizard, there's no reason to save in stages — the whole
  /// payload goes out together, so there's nothing left to partially fail
  /// between saves.
  Future<bool> _saveAll({
    required String failureMessage,
    required bool validateForPublish,
  }) async {
    if (validateForPublish && !_formKey.currentState!.validate()) {
      _showToast('Please fix the highlighted fields before continuing.',
          isError: true);
      return false;
    }
    if (validateForPublish && _requirements.isEmpty) {
      _showToast('Add at least one technical requirement before publishing.',
          isError: true);
      return false;
    }
    if (!validateForPublish &&
        (_title.text.trim().isEmpty || _overview.text.trim().isEmpty)) {
      _showToast(
        'A job title and description are required to save a draft.',
        isError: true,
      );
      return false;
    }

    final draft = JobDraft(
      title: _title.text.trim(),
      employmentType: _employmentTypeValues[_employment]!,
      workplaceType: _workplaceTypeValues[_workplace]!,
      location: _jobLocation,
      minimumSalary: double.tryParse(_minimum.text),
      maximumSalary: double.tryParse(_maximum.text),
      currency: _currency,
      description: _overview.text.trim(),
      requiredSkills: _requirements,
      minYearsOfExperience: int.tryParse(_minYears.text.trim()),
      educationLevel: _educationLevel,
      requiresManagementExperience: _requiresManagement,
      applicationDeadline: _deadline,
      aiRanking: _aiRanking,
      aiSummary: _aiSummary,
    );

    try {
      final saved = await ref.read(postJobProvider.notifier).saveJob(draft);
      if (!saved) _showError(failureMessage);
      return saved;
    } catch (_) {
      _showError(failureMessage);
      return false;
    }
  }

  Future<void> _saveDraft() async {
    if (_pendingAction != null) return;
    setState(() => _pendingAction = 'draft');
    try {
      final saved = await _saveAll(
        failureMessage: 'Could not save your job draft. Please try again.',
        validateForPublish: false,
      );
      if (!mounted) return;
      if (saved) {
        ref.invalidate(
            jobManagementProvider); // forces a fresh load() next time /jobs is shown
        _showToast('Job saved as a draft.', isError: false);
      }
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _publishJob() async {
    if (_pendingAction != null) return;
    final user = ref.read(authProvider).user;
    final monthlyLimit = (user?.limits['jobsPerMonth'] as num?)?.toInt();
    final monthlyPublished =
        ref.read(jobManagementProvider).summary?.monthlyPublishedCount;
    if (monthlyLimit != null &&
        (monthlyPublished == null || monthlyPublished >= monthlyLimit)) {
      if (monthlyPublished == null) {
        _showError(
            'Job posting usage is still loading. Please try again shortly.');
      } else {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Job posting limit reached'),
            content: Text(
                'Your plan includes $monthlyLimit job postings per month. Upgrade your subscription to post more.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Not now')),
              FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/payments');
                  },
                  child: const Text('View plans')),
            ],
          ),
        );
      }
      return;
    }
    setState(() => _pendingAction = 'publish');
    try {
      final saved = await _saveAll(
        failureMessage: 'Could not save your job. Please try again.',
        validateForPublish: true,
      );
      if (!mounted || !saved) return;
      final published = await ref.read(postJobProvider.notifier).publish();
      if (!mounted) return;
      if (published) {
        ref.invalidate(
            jobManagementProvider); // forces a fresh load() next time /jobs is shown
        _showToast('Job post published successfully.', isError: false);
        ref.read(postJobProvider.notifier).reset();
        context.go('/jobs');
      } else {
        _showError('Could not publish the job. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }
}

class _HiringPipelinePickerDialog extends StatefulWidget {
  const _HiringPipelinePickerDialog({
    required this.premiumAvailable,
    required this.customAvailable,
    required this.initialSelection,
    required this.accountName,
  });

  final bool premiumAvailable;
  final bool customAvailable;
  final String initialSelection;
  final String accountName;

  @override
  State<_HiringPipelinePickerDialog> createState() =>
      _HiringPipelinePickerDialogState();
}

class _HiringPipelinePickerDialogState
    extends State<_HiringPipelinePickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = switch (widget.initialSelection) {
      'Premium' when widget.premiumAvailable => 'Premium',
      'Custom' when widget.customAvailable => 'Custom',
      _ => 'Standard',
    };
  }

  bool _available(String tier) => switch (tier) {
        'Standard' => true,
        'Premium' => widget.premiumAvailable,
        'Custom' => widget.customAvailable,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: (screen.width - 32).clamp(240.0, 1180.0).toDouble(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screen.height * .9),
          child: Column(
            children: [
              _header(),
              _planBanner(),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  final gap = 14.0;
                  final cards = [
                    _pipelineCard(
                      tier: 'Standard',
                      level: 'TIER 1',
                      title: 'STANDARD PIPELINE',
                      description:
                          'A streamlined AI-powered hiring process for quickly identifying the strongest candidates.',
                      steps: const [
                        'Post Job',
                        'Parse',
                        'Match',
                        'Rank',
                        'Summarise',
                        'Hire',
                      ],
                      recommended:
                          'High-volume, entry-level, or rapid contractor placements.',
                    ),
                    _pipelineCard(
                      tier: 'Premium',
                      level: 'TIER 2 • FULL SUITE',
                      title: 'PREMIUM PIPELINE',
                      description:
                          'A more detailed hiring workflow with candidate assessments and comparative analytics.',
                      steps: const [
                        'Post',
                        'Parse',
                        'Match',
                        'Rank',
                        'Summary',
                        'Assess',
                        'Compare',
                        'Hire',
                      ],
                      recommended:
                          'Mid-to-senior specialized roles requiring verified skills gap validation.',
                    ),
                    _pipelineCard(
                      tier: 'Custom',
                      level: 'TIER 3 • ENTERPRISE',
                      title: 'CUSTOM PIPELINE',
                      description:
                          'Build a tailored hiring process based on bespoke multi-stage recruitment requirements.',
                      steps: const [
                        'Post',
                        'Parse',
                        'Match',
                        'Rank',
                        'Summarise',
                        'Assess 1..3',
                        'Compare',
                        'Interview',
                        'Hire',
                      ],
                      recommended:
                          'Global enterprise hiring teams with multi-stakeholder panel rounds.',
                    ),
                  ];
                  final content = wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) SizedBox(width: gap),
                              Expanded(child: cards[i]),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) SizedBox(height: gap),
                              cards[i],
                            ],
                          ],
                        );
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 22 : 16),
                    child: content,
                  );
                }),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.alt_route, color: BrandColors.orange, size: 22),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Hiring Pipeline',
                      style: TextStyle(
                          color: BrandColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                    'Choose an automated recruiting workflow. Pipelines adapt to your active subscription plan.',
                    style: TextStyle(color: BrandColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: BrandColors.muted),
            ),
          ],
        ),
      );

  Widget _planBanner() => Container(
        color: BrandColors.navy,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF0BB98A),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('YOUR PLAN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
            Text('Logged in as ${widget.accountName}',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            _planStatus('Standard', true),
            _planStatus('Premium', widget.premiumAvailable),
            _planStatus('Custom (Business Plan)', widget.customAvailable),
          ],
        ),
      );

  Widget _planStatus(String label, bool unlocked) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: unlocked
                ? ''
                : label.startsWith('Premium')
                    ? 'Your current plan doesn\'t include the Premium hiring pipeline. Upgrade your plan to unlock it.'
                    : 'Your current plan doesn\'t include custom hiring pipelines. Upgrade your plan to unlock them.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(unlocked ? Icons.check : Icons.lock_outline,
                    size: 13,
                    color: unlocked ? const Color(0xFF10C99A) : Colors.white54),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color:
                            unlocked ? const Color(0xFF10C99A) : Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );

  Widget _pipelineCard({
    required String tier,
    required String level,
    required String title,
    required String description,
    required List<String> steps,
    required String recommended,
  }) {
    final available = _available(tier);
    final selected = _selected == tier;
    final locked = !available;
    final lockedReason = tier == 'Premium'
        ? 'Your current plan doesn\'t include the Premium hiring pipeline. Upgrade your plan to unlock it.'
        : 'Your current plan doesn\'t include custom hiring pipelines. Upgrade your plan to unlock them.';
    return Tooltip(
      message: locked ? lockedReason : '',
      child: SizedBox(
        height: 470,
        child: Opacity(
          opacity: locked ? .56 : 1,
          child: InkWell(
            onTap: available ? () => setState(() => _selected = tier) : null,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 405),
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                  decoration: BoxDecoration(
                    color: locked ? const Color(0xFFF1F5F9) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? BrandColors.orange
                          : const Color(0xFFE0E7F0),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                                color: Color(0x1CFF7417),
                                blurRadius: 12,
                                offset: Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(level,
                              style: TextStyle(
                                  color: locked
                                      ? const Color(0xFF9EADC0)
                                      : tier == 'Premium' && selected
                                          ? BrandColors.orange
                                          : const Color(0xFF8798B0),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6)),
                        ),
                        _availabilityChip(available),
                      ]),
                      const SizedBox(height: 14),
                      Text(title,
                          style: TextStyle(
                              color: locked
                                  ? const Color(0xFF8798B0)
                                  : BrandColors.navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(description,
                          style: TextStyle(
                              color: locked
                                  ? const Color(0xFF9AA9BB)
                                  : BrandColors.muted,
                              fontSize: 11,
                              height: 1.5)),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFE6ECF3)),
                      const SizedBox(height: 12),
                      const Text('PROCESS STEPS',
                          style: TextStyle(
                              color: Color(0xFF91A0B6),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .3)),
                      const SizedBox(height: 8),
                      _processSteps(steps, locked),
                      const SizedBox(height: 15),
                      const Text('RECOMMENDED FOR',
                          style: TextStyle(
                              color: Color(0xFF91A0B6),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .3)),
                      const SizedBox(height: 6),
                      Text(recommended,
                          style: TextStyle(
                              color: locked
                                  ? const Color(0xFF9AA9BB)
                                  : BrandColors.muted,
                              fontSize: 11,
                              height: 1.4)),
                      const Spacer(),
                      const Divider(height: 18, color: Color(0xFFE6ECF3)),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: available
                              ? () => setState(() => _selected = tier)
                              : null,
                          icon: Icon(locked ? Icons.lock_outline : Icons.check,
                              size: 14),
                          label: Text(locked
                              ? 'Available on ${tier == 'Custom' ? 'Business' : 'Premium'}'
                              : selected
                                  ? 'Active Selection'
                                  : 'Select $tier'),
                          style: FilledButton.styleFrom(
                            backgroundColor: selected
                                ? BrandColors.orange
                                : const Color(0xFFF0F4F8),
                            foregroundColor:
                                selected ? Colors.white : BrandColors.navy,
                            disabledBackgroundColor: const Color(0xFFE3E9F0),
                            disabledForegroundColor: const Color(0xFF8798AA),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                      if (locked && tier == 'Custom') ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                              'Upgrade to Business Plan to build custom stages',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF8798AA), fontSize: 8.5)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                            color: BrandColors.orange,
                            borderRadius: BorderRadius.circular(14)),
                        child: const Text('SELECTED CURRENT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _availabilityChip(bool available) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: available ? const Color(0xFFE9FBF5) : const Color(0xFFE4EAF1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: available
                  ? const Color(0xFFAAEED8)
                  : const Color(0xFFDCE4EC)),
        ),
        child: Text(available ? 'Available' : 'Locked',
            style: TextStyle(
                color: available
                    ? const Color(0xFF169B75)
                    : const Color(0xFF78899F),
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      );

  Widget _processSteps(List<String> steps, bool locked) {
    final color = locked ? const Color(0xFF8798AA) : BrandColors.navy;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 5,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            const Text('→',
                style: TextStyle(color: Color(0xFF9AA8B9), fontSize: 9)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: steps[i] == 'Hire'
                  ? const Color(0xFFE4F8F1)
                  : steps[i] == 'Compare'
                      ? BrandColors.orange
                      : steps[i] == 'Assess'
                          ? BrandColors.navy
                          : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(steps[i],
                style: TextStyle(
                    color: steps[i] == 'Compare' || steps[i] == 'Assess'
                        ? Colors.white
                        : steps[i] == 'Hire'
                            ? const Color(0xFF118D69)
                            : color,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _footer() => LayoutBuilder(builder: (context, constraints) {
        final actions = Wrap(
          alignment: WrapAlignment.end,
          spacing: 9,
          runSpacing: 8,
          children: [
            OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Confirm Pipeline Choice'),
            ),
          ],
        );
        final help = Wrap(
          children: [
            const Text('Need help selecting? ',
                style: TextStyle(color: BrandColors.muted, fontSize: 10)),
            GestureDetector(
              onTap: () => AppToast.info(
                  context, 'Pipeline documentation is coming soon.'),
              child: const Text('Review Pipeline Documentation',
                  style: TextStyle(
                      color: BrandColors.orange,
                      fontSize: 10,
                      decoration: TextDecoration.underline)),
            ),
          ],
        );
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 13, 22, 14),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE4EAF2)))),
          child: constraints.maxWidth < 620
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    help,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: help),
                    actions,
                  ],
                ),
        );
      });
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: const TextStyle(fontSize: 7.5, color: BrandColors.muted)));
}

final _draftButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: BrandColors.navy,
    side: const BorderSide(color: Color(0xFFDCE4EF)),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)));
