import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/brand_color.dart';
import '../../hiring_pipeline/application/hiring_pipeline_provider.dart';
import '../../hiring_pipeline/data/models/hiring_pipeline_model.dart';
import '../../jobs/application/application_provider.dart';
import '../../jobs/application/job_management_provider.dart';
import '../../jobs/data/models/application_model.dart';
import '../application/assessment_provider.dart';

class AssessmentCreateScreen extends ConsumerStatefulWidget {
  const AssessmentCreateScreen({
    super.key,
    this.testId,
    this.initialJobId,
    this.initialPipelineId,
  });
  final String? testId;
  final String? initialJobId;
  final String? initialPipelineId;
  @override
  ConsumerState<AssessmentCreateScreen> createState() =>
      _AssessmentCreateScreenState();
}

class _AssessmentCreateScreenState
    extends ConsumerState<AssessmentCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _purpose = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _passing = TextEditingController(text: '75');
  final _externalLink = TextEditingController();
  String? _jobId;
  String? _pipelineId;
  String? _stageName;
  String _mode = 'manual';
  String _kind = 'internal';
  String _channel = 'email';
  bool _includeShortlisted = false;
  bool _reminder = true;
  bool _autoInviteShortlisted = true;
  bool _autoGenerateAfterDeadline = true;
  bool _initialPipelineDefaultsApplied = false;
  bool _pipelineGenerationQueued = false;
  DateTime? _availableFrom;
  DateTime? _availableUntil;
  DateTime? _reminderBefore;
  String? _testId;
  bool _busy = false;
  List<Map<String, dynamic>> _questions = [];
  final Set<String> _selectedApplications = {};

  @override
  void initState() {
    super.initState();
    _testId = widget.testId;
    _jobId = widget.initialJobId;
    _pipelineId = widget.initialPipelineId;
    _availableFrom = DateTime.now().add(const Duration(minutes: 5));
    _availableUntil = DateTime.now().add(const Duration(days: 3));
    _reminderBefore = DateTime.now().add(const Duration(days: 2));
    if (_testId != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _purpose.dispose();
    _duration.dispose();
    _passing.dispose();
    _externalLink.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final test =
          await ref.read(assessmentRepositoryProvider).getAssessment(_testId!);
      if (!mounted) return;
      setState(() {
        _title.text = test['title']?.toString() ?? '';
        _purpose.text = test['purpose']?.toString() ?? '';
        _duration.text = '${test['durationMinutes'] ?? 60}';
        _passing.text = '${test['passingScore'] ?? 75}';
        _externalLink.text = test['externalLink']?.toString() ?? '';
        _jobId = test['jobId'] is Map
            ? test['jobId']['_id']?.toString()
            : test['jobId']?.toString();
        _pipelineId = test['pipelineId']?.toString();
        _stageName = test['pipelineStageName']?.toString();
        _mode = test['generationMode']?.toString() == 'ai_generated'
            ? 'ai_assisted'
            : test['generationMode']?.toString() ?? 'manual';
        _kind = test['assessmentKind']?.toString() ?? 'internal';
        _channel = test['deliveryChannel']?.toString() ?? 'email';
        _includeShortlisted = test['autoInviteShortlisted'] == true;
        _autoInviteShortlisted = test['autoInviteShortlisted'] != false;
        _autoGenerateAfterDeadline = test['autoGenerateAfterDeadline'] == true;
        _availableFrom =
            DateTime.tryParse(test['availableFrom']?.toString() ?? '');
        _availableUntil =
            DateTime.tryParse(test['availableUntil']?.toString() ?? '');
        _reminder = test['reminderMinutesBefore'] != null;
        _questions = (test['questions'] as List? ?? const []).map((q) {
          final item = Map<String, dynamic>.from(q as Map);
          item['accepted'] = _mode != 'ai_assisted';
          return item;
        }).toList();
      });
    } catch (e) {
      _showError(e);
    }
  }

  Map<String, dynamic> _payload({bool forUpdate = false}) {
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'purpose': _purpose.text.trim(),
      'generationMode': _kind == 'external' ? 'manual' : _mode,
      'assessmentKind': _kind,
      'deliveryChannel': _channel,
      'durationMinutes': int.tryParse(_duration.text) ?? 60,
      'passingScore': int.tryParse(_passing.text) ?? 75,
      'questions': _kind == 'internal'
          ? _questions
              .where((q) => q['accepted'] != false)
              .map(_serializeQuestion)
              .toList()
          : <Map<String, dynamic>>[],
      'autoInviteShortlisted': _mode == 'full_ai' && _autoInviteShortlisted,
      'autoGenerateAfterDeadline':
          _mode == 'full_ai' && _autoGenerateAfterDeadline,
    };
    if (_stageName != null && _stageName!.trim().isNotEmpty) {
      payload['pipelineStageName'] = _stageName!.trim();
    }
    if (!forUpdate) {
      payload['jobId'] = _jobId;
      if (_pipelineId != null) payload['pipelineId'] = _pipelineId;
      payload['questionsPerSkill'] = 2;
      if (_testId != null) payload['testId'] = _testId;
    }
    if (_kind == 'external' && _externalLink.text.trim().isNotEmpty)
      payload['externalLink'] = _externalLink.text.trim();
    if (_availableFrom != null)
      payload['availableFrom'] = _availableFrom!.toUtc().toIso8601String();
    if (_availableUntil != null)
      payload['availableUntil'] = _availableUntil!.toUtc().toIso8601String();
    if (_reminder && _availableUntil != null && _reminderBefore != null) {
      final minutes = _availableUntil!.difference(_reminderBefore!).inMinutes;
      if (minutes >= 0) payload['reminderMinutesBefore'] = minutes;
    }
    return payload;
  }

  Map<String, dynamic> _serializeQuestion(Map<String, dynamic> question) => {
        'questionId':
            question['questionId']?.toString() ?? UniqueKey().toString(),
        'text': question['text']?.toString() ?? '',
        'type': question['type']?.toString() ?? 'multiple_choice',
        'skillCategory': question['skillCategory']?.toString() ?? 'General',
        'points': (question['points'] as num?)?.toInt() ?? 10,
        if (question['type'] != 'multiple_choice') ...{
          'referenceAnswer':
              question['referenceAnswer']?.toString().trim() ?? '',
          'gradingRubric': question['gradingRubric']?.toString().trim() ?? '',
        },
        if (question['type'] == 'multiple_choice') ...{
          'options': (question['options'] as List? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.trim().isNotEmpty)
              .toList(),
          if (question['correctAnswer'] != null)
            'correctAnswer': question['correctAnswer'].toString().trim(),
        },
      };

  Future<void> _generate({bool append = false}) async {
    if (!_validateBasics()) return;
    setState(() => _busy = true);
    try {
      // Full AI mode can also schedule publication after the deadline. Generate
      // the assessment content now so recruiters can review it before saving
      // the draft or scheduling shortlist invitations.
      final payload = _payload()
        ..['appendQuestions'] = append
        ..['autoGenerateAfterDeadline'] = false;
      final generated =
          await ref.read(assessmentRepositoryProvider).generate(payload);
      final existingAcceptance = {
        for (final question in _questions)
          if (question['questionId'] != null)
            question['questionId'].toString(): question['accepted'] ?? true,
      };
      final questions = (generated['questions'] as List? ?? const []).map((q) {
        final item = Map<String, dynamic>.from(q as Map);
        item['accepted'] = existingAcceptance[item['questionId']?.toString()] ??
            _mode != 'ai_assisted';
        return item;
      }).toList();
      setState(() {
        _testId = (generated['_id'] ?? generated['id']).toString();
        _questions = questions;
      });
      ref.invalidate(recruiterAssessmentsProvider);
      if (questions.isEmpty && _kind == 'internal')
        throw StateError('AI returned no questions. Try again.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validateBasics() {
    if (!_formKey.currentState!.validate()) return false;
    if (_jobId == null) {
      _showError(StateError('Choose a job first.'));
      return false;
    }
    if (_availableUntil != null &&
        _availableFrom != null &&
        !_availableUntil!.isAfter(_availableFrom!)) {
      _showError(StateError('The end date and time must be after the start.'));
      return false;
    }
    if (_kind == 'internal') {
      for (var index = 0; index < _questions.length; index++) {
        final question = _questions[index];
        if (question['accepted'] == false ||
            question['type'] != 'multiple_choice') continue;
        final options = (question['options'] as List? ?? const [])
            .map((option) => option.toString().trim())
            .where((option) => option.isNotEmpty)
            .toSet();
        if (options.length < 2) {
          _showError(StateError(
              'Question ${index + 1} needs at least two answer options.'));
          return false;
        }
        if (!options.contains(question['correctAnswer']?.toString().trim())) {
          _showError(StateError(
              'Choose the correct answer for question ${index + 1}.'));
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _saveDraft() async {
    if (!_validateBasics()) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(assessmentRepositoryProvider);
      if (_mode == 'manual' || _kind == 'external') {
        final payload = _payload()
          ..['generationMode'] = _mode
          ..['autoGenerateAfterDeadline'] = false;
        final saved = _testId == null
            ? await repo.createManual(payload)
            : await repo.update(_testId!, payload);
        _testId = (saved['_id'] ?? saved['id'] ?? _testId).toString();
      } else {
        if (_testId == null) await _generate();
        if (_testId == null) {
          throw StateError('The assessment could not be generated. Try again.');
        }
        final draftPayload = _payload(forUpdate: true)
          ..['autoGenerateAfterDeadline'] = false;
        await repo.update(_testId!, draftPayload);
      }
      ref.invalidate(recruiterAssessmentsProvider);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft saved.')));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (!_validateBasics()) return;
    if (_kind == 'internal' &&
        _mode == 'ai_assisted' &&
        (_testId == null || _questions.isEmpty)) {
      await _generate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'AI questions generated. Review and accept them before publishing.'),
        ));
      }
      return;
    }
    if (_kind == 'internal' &&
        _mode == 'ai_assisted' &&
        _questions.any((q) => q['accepted'] == false)) {
      _showError(
          StateError('Review or remove every AI question before publishing.'));
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(assessmentRepositoryProvider);
      if (_testId == null) {
        if (_mode == 'manual' || _kind == 'external') {
          final saved =
              await repo.createManual(_payload()..['generationMode'] = _mode);
          _testId = (saved['_id'] ?? saved['id']).toString();
        } else {
          final payload = _payload()
            ..['generationMode'] = _mode
            ..['autoGenerateAfterDeadline'] = false;
          final saved = await repo.generate(payload);
          _testId = (saved['_id'] ?? saved['id']).toString();
          _questions = (saved['questions'] as List? ?? const [])
              .map((q) => Map<String, dynamic>.from(q as Map)
                ..['accepted'] = _mode != 'ai_assisted')
              .toList();
        }
      } else {
        await repo.update(_testId!, _payload(forUpdate: true));
      }
      if (_mode == 'full_ai' && _autoGenerateAfterDeadline) {
        ref.invalidate(recruiterAssessmentsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Automatic assessment scheduled for the job application deadline.'),
          ));
          context.go('/competency-assessments/$_testId');
        }
        return;
      }
      await repo.publish(
        _testId!,
        applicationIds: _selectedApplications.toList(),
        includeShortlisted: _includeShortlisted ||
            (_mode == 'full_ai' && _autoInviteShortlisted),
        deliveryChannel: _channel,
      );
      ref.invalidate(recruiterAssessmentsProvider);
      if (mounted) context.go('/competency-assessments/$_testId');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(error.toString())));

  void _addQuestion() => setState(() => _questions.add({
        'questionId': UniqueKey().toString(),
        'text': '',
        'type': 'multiple_choice',
        'skillCategory': 'Technical Proficiency',
        'options': ['Option A', 'Option B', 'Option C', 'Option D'],
        'correctAnswer': 'Option A',
        'points': 10,
        'accepted': true,
      }));

  @override
  Widget build(BuildContext context) {
    final jobsState = ref.watch(jobManagementProvider);
    final jobs = jobsState.summary?.postings ?? const [];
    _jobId ??= jobs.isNotEmpty ? jobs.first.id : null;
    final pipelineState = ref.watch(pipelinesProvider);
    final pipelines = pipelineState.value ?? const <HiringPipeline>[];
    if (!_initialPipelineDefaultsApplied &&
        widget.initialPipelineId != null &&
        pipelineState.hasValue) {
      final initialPipeline = pipelines
          .where((pipeline) => pipeline.id == widget.initialPipelineId)
          .firstOrNull;
      if (initialPipeline != null) {
        _applyPipelineDefaults(initialPipeline);
        _initialPipelineDefaultsApplied = true;
      }
    }
    if (_pipelineId == null &&
        pipelines.isNotEmpty &&
        widget.initialJobId == null) {
      _pipelineId = pipelines.first.id;
      _applyPipelineDefaults(pipelines.first);
      _initialPipelineDefaultsApplied = true;
    }
    final selectedPipeline =
        pipelines.where((pipeline) => pipeline.id == _pipelineId).firstOrNull;
    final assessmentStages = selectedPipeline?.stages
            .where((stage) => isAssessmentType(stage.type))
            .toList(growable: false) ??
        const <PipelineStage>[];
    final assessmentStage = assessmentStages.firstOrNull;
    if (_stageName == null && assessmentStage != null)
      _stageName = assessmentStage.name;
    if (assessmentStage?.assessmentMode.toLowerCase() == 'auto' &&
        !_pipelineGenerationQueued &&
        _testId == null) {
      _pipelineGenerationQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final job = jobs.where((item) => item.id == _jobId).firstOrNull;
        if (job == null) {
          _pipelineGenerationQueued = false;
          return;
        }
        setState(() {
          _title.text = _title.text.trim().isEmpty
              ? '${job.title} assessment'
              : _title.text;
          _purpose.text = _purpose.text.trim().isEmpty
              ? 'Evaluate candidates for ${job.title} using the role requirements.'
              : _purpose.text;
        });
        await _generate();
      });
    }
    final applicationsState =
        _jobId == null ? null : ref.watch(jobApplicantsProvider(_jobId!));

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextButton.icon(
                  onPressed: () => context.go('/competency-assessments'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Assessments')),
              LayoutBuilder(builder: (context, constraints) {
                final isEditing = _testId != null;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Edit Competency Assessment'
                          : 'Create Competency Assessment',
                      style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: BrandColors.navy),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                        'Build a structured assessment to evaluate candidate competencies.'),
                  ],
                );
                final actions = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _saveDraft,
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Save draft'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy ? null : _publish,
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: Text(_busy
                          ? 'Saving…'
                          : isEditing
                              ? (_mode == 'full_ai' &&
                                      _autoGenerateAfterDeadline
                                  ? 'Schedule assessment'
                                  : 'Save & publish')
                              : (_mode == 'full_ai' &&
                                      _autoGenerateAfterDeadline
                                  ? 'Schedule & invite shortlist'
                                  : 'Publish & invite')),
                      style: FilledButton.styleFrom(
                          backgroundColor: BrandColors.orange),
                    ),
                  ],
                );
                return constraints.maxWidth < 700
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          const SizedBox(height: 14),
                          actions,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 16),
                          actions,
                        ],
                      );
              }),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final config = _buildConfiguration(
                    jobs, pipelines, applicationsState, assessmentStages);
                final summary = _buildSummary(assessmentStage);
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    config,
                    if (_kind == 'internal') ...[
                      const SizedBox(height: 14),
                      _buildAiBanner(),
                    ],
                    const SizedBox(height: 14),
                    _buildQuestions(),
                  ],
                );
                if (constraints.maxWidth < 800) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      config,
                      const SizedBox(height: 14),
                      summary,
                      if (_kind == 'internal') ...[
                        const SizedBox(height: 14),
                        _buildAiBanner(),
                      ],
                      const SizedBox(height: 14),
                      _buildQuestions(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: main),
                    const SizedBox(width: 18),
                    SizedBox(width: 264, child: summary),
                  ],
                );
              }),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildConfiguration(
          List jobs,
          List<HiringPipeline> pipelines,
          JobApplicantsState? applicationsState,
          List<PipelineStage> assessmentStages) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Configuration & schedule',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                        value:
                            jobs.any((job) => job.id == _jobId) ? _jobId : null,
                        decoration: const InputDecoration(labelText: 'Job'),
                        items: [
                          for (final job in jobs)
                            DropdownMenuItem<String>(
                                value: job.id,
                                child: Text(job.title,
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                  _jobId = value;
                                  _selectedApplications.clear();
                                }),
                        validator: (value) =>
                            value == null ? 'Choose a job' : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(
                            labelText: 'Assessment title'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a title'
                                : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _purpose,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Evaluation purpose / instructions')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: pipelines
                                .any((pipeline) => pipeline.id == _pipelineId)
                            ? _pipelineId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Hiring pipeline'),
                        items: [
                          for (final pipeline in pipelines)
                            DropdownMenuItem(
                                value: pipeline.id, child: Text(pipeline.name))
                        ],
                        onChanged: (value) => setState(() {
                              _pipelineId = value;
                              final chosen = pipelines
                                  .where((p) => p.id == value)
                                  .firstOrNull;
                              _stageName = chosen?.stages
                                  .where((s) => isAssessmentType(s.type))
                                  .firstOrNull
                                  ?.name;
                              if (chosen != null)
                                _applyPipelineDefaults(chosen);
                            })),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: assessmentStages
                                .any((stage) => stage.name == _stageName)
                            ? _stageName
                            : null,
                        decoration: const InputDecoration(
                            labelText: 'Assessment stage'),
                        items: [
                          for (final stage in assessmentStages)
                            DropdownMenuItem(
                                value: stage.name, child: Text(stage.name))
                        ],
                        onChanged: (value) {
                          final stage = pipelines
                              .where((pipeline) => pipeline.id == _pipelineId)
                              .firstOrNull
                              ?.stages
                              .where((item) => item.name == value)
                              .firstOrNull;
                          setState(() {
                            _stageName = value;
                            if (stage != null) _applyStageDefaults(stage);
                          });
                        }),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: _kind,
                        decoration: const InputDecoration(
                            labelText: 'Assessment source'),
                        items: const [
                          DropdownMenuItem(
                              value: 'internal',
                              child: Text('Build assessment in TalentBridge')),
                          DropdownMenuItem(
                              value: 'external',
                              child: Text('External assessment link'))
                        ],
                        onChanged: (value) => setState(() {
                              _kind = value ?? 'internal';
                              if (_kind == 'external') _mode = 'manual';
                            })),
                    if (_kind == 'internal') ...[
                      const SizedBox(height: 12),
                      const Text('Creation mode',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BrandColors.navy)),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        _modeChoice('manual', 'Manual'),
                        _modeChoice('ai_assisted', 'AI assisted'),
                        _modeChoice('full_ai', 'Full AI automation'),
                      ]),
                    ],
                    if (_kind == 'external') ...[
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: _externalLink,
                          decoration: const InputDecoration(
                              labelText: 'External HTTPS link'),
                          validator: (value) => _kind == 'external' &&
                                  (value == null ||
                                      !value.startsWith('https://'))
                              ? 'Enter an HTTPS link'
                              : null),
                    ],
                    if (_kind == 'internal') ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _numberField(_duration, 'Duration (minutes)',
                                min: 1, max: 600)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _numberField(_passing, 'Passing score (%)',
                                min: 0, max: 100))
                      ]),
                    ],
                    const SizedBox(height: 14),
                    const Text('Assessment window',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: () => _pickDateTime(start: true),
                          icon: const Icon(Icons.schedule),
                          label: Text(_dateLabel(_availableFrom, 'Set start'))),
                      OutlinedButton.icon(
                          onPressed: () => _pickDateTime(start: false),
                          icon: const Icon(Icons.event),
                          label: Text(_dateLabel(_availableUntil, 'Set end'))),
                    ]),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                            'Send candidate reminder before closing'),
                        value: _reminder,
                        onChanged: (value) =>
                            setState(() => _reminder = value)),
                    if (_reminder)
                      OutlinedButton.icon(
                          onPressed: _pickReminder,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                              'Reminder: ${_dateLabel(_reminderBefore, 'Choose reminder time')}')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: _channel,
                        decoration: const InputDecoration(
                            labelText: 'Invitation channel'),
                        items: const [
                          DropdownMenuItem(
                              value: 'email', child: Text('Email')),
                          DropdownMenuItem(
                              value: 'message', child: Text('In-app message')),
                          DropdownMenuItem(
                              value: 'both',
                              child: Text('Email and in-app message'))
                        ],
                        onChanged: (value) =>
                            setState(() => _channel = value ?? 'email')),
                    if (_mode == 'full_ai') ...[
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                              'Generate assessment after job application deadline'),
                          subtitle: const Text(
                              'Questions are generated now for your review. At the job deadline, the assessment is published to shortlisted candidates and stays open for 7 days.'),
                          value: _autoGenerateAfterDeadline,
                          onChanged: (value) => setState(
                              () => _autoGenerateAfterDeadline = value)),
                      if (!_autoGenerateAfterDeadline)
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                                'Automatically invite shortlisted candidates on publish'),
                            value: _autoInviteShortlisted,
                            onChanged: (value) =>
                                setState(() => _autoInviteShortlisted = value)),
                    ],
                    const Divider(height: 24),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include all shortlisted candidates'),
                        value: _includeShortlisted,
                        onChanged: (value) =>
                            setState(() => _includeShortlisted = value)),
                    if (applicationsState == null)
                      const Text('Choose a job to select applicants.')
                    else if (applicationsState.isLoading)
                      const LinearProgressIndicator()
                    else
                      ...applicationsState.applications
                          .map((application) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _selectedApplications
                                    .contains(application.id),
                                title: Text(
                                    '${application.candidate.firstName} ${application.candidate.lastName}'),
                                subtitle: Text(application.status.label),
                                onChanged: (value) => setState(() {
                                  if (value == true)
                                    _selectedApplications.add(application.id);
                                  else
                                    _selectedApplications
                                        .remove(application.id);
                                }),
                              )),
                  ])));

  Widget _buildSummary(PipelineStage? stage) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assessment summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Divider(height: 24),
            _summaryLine('Status', _testId == null ? 'Draft' : 'Saved draft'),
            _summaryLine('Questions',
                '${_questions.where((q) => q['accepted'] != false).length}'),
            _summaryLine('Total score',
                '${_questions.where((q) => q['accepted'] != false).fold<int>(0, (sum, q) => sum + ((q['points'] as num?)?.toInt() ?? 10))} pts'),
            _summaryLine('Duration',
                '${int.tryParse(_duration.text) ?? stage?.durationMins ?? 60} min'),
            _summaryLine('Passing score',
                '${int.tryParse(_passing.text) ?? stage?.passingScore ?? 75}%'),
            _summaryLine('Pipeline stage', _stageName ?? 'Not selected'),
            const SizedBox(height: 14),
            const Text('Candidate monitoring',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
                'Candidates are warned when they switch tabs or leave the assessment. Repeated focus changes are recorded.',
                style: TextStyle(fontSize: 12, color: BrandColors.muted)),
          ])));

  Widget _buildAiBanner() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [BrandColors.navy, Color(0xFF342C35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final action = FilledButton.icon(
            onPressed: _busy
                ? null
                : () {
                    if (_mode == 'manual') {
                      setState(() => _mode = 'ai_assisted');
                    }
                    _generate(append: _questions.isNotEmpty);
                  },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(_busy
                ? 'Generating…'
                : _questions.isEmpty
                    ? 'Generate questions with AI'
                    : 'Generate more questions'),
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome, color: BrandColors.orange),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text('Generate with AI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: BrandColors.orange,
                      borderRadius: BorderRadius.circular(5)),
                  child: const Text('AI ASSISTED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Draft role specific questions from your competency settings, then review and edit every question before candidates see them.',
                style: TextStyle(color: Color(0xFFD3D5DF), height: 1.45),
              ),
            ],
          );
          return constraints.maxWidth < 540
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 14), action],
                )
              : Row(children: [
                  Expanded(child: copy),
                  const SizedBox(width: 18),
                  Flexible(child: action),
                ]);
        }),
      );

  Widget _buildQuestions() {
    if (_kind == 'external')
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                  'External assessment selected. Candidates will receive your HTTPS link.')));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Questions',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(
                          'AI-assisted questions remain editable until you publish.')
                    ])),
                if (_mode != 'manual')
                  OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _generate(append: _questions.isNotEmpty),
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_questions.isEmpty
                          ? 'Generate questions'
                          : 'Generate more')),
                if (_mode == 'ai_assisted' &&
                    _questions.any((q) => q['accepted'] == false))
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              for (final question in _questions) {
                                question['accepted'] = true;
                              }
                            }),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Accept all'),
                  ),
                if (_mode == 'manual')
                  OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Add question')),
              ]))),
      if (_questions.isEmpty)
        const Padding(
            padding: EdgeInsets.all(22),
            child: Center(
                child: Text(
                    'Add questions manually or generate a draft with AI.'))),
      for (var index = 0; index < _questions.length; index++)
        _QuestionEditor(
          key: ValueKey(_questions[index]['questionId']),
          index: index + 1,
          question: _questions[index],
          onChanged: (key, value) =>
              setState(() => _questions[index][key] = value),
          onAccept: () => setState(() => _questions[index]['accepted'] = true),
          onReject: () => setState(() => _questions.removeAt(index)),
          onDelete: () => setState(() => _questions.removeAt(index)),
          generated: _mode != 'manual',
        ),
      if (_mode == 'manual')
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Add question'))),
    ]);
  }

  Widget _modeChoice(String value, String label) => ChoiceChip(
      label: Text(label),
      selected: _mode == value,
      onSelected: (_) => setState(() => _mode = value));
  Widget _numberField(TextEditingController controller, String label,
          {required int min, required int max}) =>
      TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number < min || number > max
                ? 'Enter $min–$max'
                : null;
          });
  Widget _summaryLine(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(
            child:
                Text(label, style: const TextStyle(color: BrandColors.muted))),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]));
  String _dateLabel(DateTime? value, String empty) => value == null
      ? empty
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _applyPipelineDefaults(HiringPipeline pipeline) {
    final stage = pipeline.stages
        .where((item) => isAssessmentType(item.type))
        .firstOrNull;
    if (stage == null) return;
    _applyStageDefaults(stage);
  }

  void _applyStageDefaults(PipelineStage stage) {
    _stageName = stage.name;
    _duration.text = '${stage.durationMins}';
    _passing.text = '${stage.passingScore}';
    _mode = switch (stage.assessmentMode.toLowerCase()) {
      'manual' => 'manual',
      'auto' || 'full_ai' => 'full_ai',
      _ => 'ai_assisted',
    };
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current =
        (start ? _availableFrom : _availableUntil) ?? DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    setState(() {
      final chosen =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (start) {
        _availableFrom = chosen;
      } else {
        _availableUntil = chosen;
      }
    });
  }

  Future<void> _pickReminder() async {
    final picked = await showDatePicker(
        context: context,
        initialDate:
            _reminderBefore ?? DateTime.now().add(const Duration(days: 2)),
        firstDate: DateTime.now(),
        lastDate:
            _availableUntil ?? DateTime.now().add(const Duration(days: 365)));
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_reminderBefore ?? picked));
    if (time != null)
      setState(() => _reminderBefore = DateTime(
          picked.year, picked.month, picked.day, time.hour, time.minute));
  }
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor(
      {super.key,
      required this.index,
      required this.question,
      required this.onChanged,
      required this.onAccept,
      required this.onReject,
      required this.onDelete,
      required this.generated});
  final int index;
  final Map<String, dynamic> question;
  final void Function(String key, dynamic value) onChanged;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDelete;
  final bool generated;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final List<TextEditingController> _optionControllers;
  int? _correctOptionIndex;

  @override
  void initState() {
    super.initState();
    final options = (widget.question['options'] as List? ?? const [])
        .map((option) => option.toString())
        .toList();
    if (options.isEmpty) options.addAll(['', '']);
    _optionControllers =
        options.map((option) => TextEditingController(text: option)).toList();
    final correctAnswer = widget.question['correctAnswer']?.toString().trim();
    final correctIndex = options.indexOf(correctAnswer ?? '');
    _correctOptionIndex =
        correctAnswer == null || correctAnswer.isEmpty || correctIndex < 0
            ? null
            : correctIndex;
  }

  @override
  void dispose() {
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _labelFor(int index) =>
      index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

  void _syncOptions() {
    widget.onChanged('options',
        _optionControllers.map((controller) => controller.text).toList());
    final correctIndex = _correctOptionIndex;
    if (correctIndex != null && correctIndex < _optionControllers.length) {
      widget.onChanged(
          'correctAnswer', _optionControllers[correctIndex].text.trim());
    }
  }

  void _selectCorrectOption(int index) {
    setState(() => _correctOptionIndex = index);
    widget.onChanged('correctAnswer', _optionControllers[index].text.trim());
  }

  void _addOption() {
    setState(() => _optionControllers.add(TextEditingController()));
    _syncOptions();
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final removed = _optionControllers.removeAt(index);
    removed.dispose();
    if (_correctOptionIndex == index) {
      _correctOptionIndex = null;
      widget.onChanged('correctAnswer', '');
    } else if (_correctOptionIndex != null && _correctOptionIndex! > index) {
      _correctOptionIndex = _correctOptionIndex! - 1;
    }
    setState(() {});
    _syncOptions();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.question['type']?.toString() ?? 'multiple_choice';
    final correctIndex = _correctOptionIndex;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BrandColors.border),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: BrandColors.orange, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'QUESTION ${widget.index}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .45,
                    color: BrandColors.muted,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: type,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Multiple choice'),
                        ),
                        DropdownMenuItem(
                          value: 'text',
                          child: Text('Written response'),
                        ),
                        DropdownMenuItem(
                          value: 'code',
                          child: Text('Code response'),
                        ),
                      ],
                      onChanged: (value) => widget.onChanged('type', value),
                    ),
                    IconButton(
                      tooltip: 'Delete question',
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.question['text']?.toString(),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Question prompt',
                alignLabelWithHint: true,
              ),
              onChanged: (value) => widget.onChanged('text', value),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackFields = constraints.maxWidth < 440;
                final competency = TextFormField(
                  initialValue: widget.question['skillCategory']?.toString(),
                  decoration: const InputDecoration(labelText: 'Competency'),
                  onChanged: (value) =>
                      widget.onChanged('skillCategory', value),
                );
                final points = TextFormField(
                  initialValue: '${widget.question['points'] ?? 10}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points'),
                  onChanged: (value) =>
                      widget.onChanged('points', int.tryParse(value) ?? 1),
                );
                return stackFields
                    ? Column(
                        children: [
                          competency,
                          const SizedBox(height: 10),
                          points,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: competency),
                          const SizedBox(width: 12),
                          SizedBox(width: 110, child: points),
                        ],
                      );
              },
            ),
            if (type == 'multiple_choice') ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Answer options',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy,
                      ),
                    ),
                  ),
                  Text(
                    'Select the correct answer',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: BrandColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0;
                  index < _optionControllers.length;
                  index++) ...[
                _RecruiterOptionRow(
                  index: index,
                  label: _labelFor(index),
                  controller: _optionControllers[index],
                  selected: correctIndex == index,
                  canRemove: _optionControllers.length > 2,
                  onMakeCorrect: () => _selectCorrectOption(index),
                  onRemove: () => _removeOption(index),
                  onChanged: (_) => _syncOptions(),
                ),
                const SizedBox(height: 6),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _optionControllers.length < 8 ? _addOption : null,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add option'),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandColors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ),
            ],
            if (type != 'multiple_choice') ...[
              const SizedBox(height: 14),
              TextFormField(
                initialValue: widget.question['referenceAnswer']?.toString(),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reference answer (recruiter only)',
                  helperText:
                      'Used to guide AI scoring; candidates will not see it.',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) =>
                    widget.onChanged('referenceAnswer', value),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: widget.question['gradingRubric']?.toString(),
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Scoring criteria',
                  helperText: 'Describe what earns full or partial credit.',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => widget.onChanged('gradingRubric', value),
              ),
            ],
            const Divider(height: 20),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 210),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: BrandColors.navy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.question['skillCategory']?.toString() ??
                        'Competency',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                Text(
                  'Points: ${widget.question['points'] ?? 10} pts',
                  style: const TextStyle(
                    color: BrandColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.generated) ...[
                  Text(
                    widget.question['accepted'] == true
                        ? 'AI draft · accepted for review'
                        : 'AI draft · review required',
                    style:
                        const TextStyle(color: BrandColors.muted, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: widget.onReject,
                    child: const Text('Reject'),
                  ),
                  FilledButton.tonal(
                    onPressed: widget.onAccept,
                    child: const Text('Accept'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecruiterOptionRow extends StatelessWidget {
  const _RecruiterOptionRow({
    required this.index,
    required this.label,
    required this.controller,
    required this.selected,
    required this.canRemove,
    required this.onMakeCorrect,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final String label;
  final TextEditingController controller;
  final bool selected;
  final bool canRemove;
  final VoidCallback onMakeCorrect;
  final VoidCallback onRemove;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final marker = InkWell(
      onTap: onMakeCorrect,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? BrandColors.orange : const Color(0xFFE5E7EB),
          shape: BoxShape.circle,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 17)
            : Text(
                label,
                style: const TextStyle(
                  color: BrandColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
    final optionField = TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Option $label',
        isDense: true,
        filled: selected,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: BrandColors.orange, width: 1.2),
        ),
      ),
    );
    final correctAction = selected
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E3),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'CORRECT ANSWER',
              style: TextStyle(
                color: BrandColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
          )
        : IconButton(
            tooltip: 'Mark as correct answer',
            visualDensity: VisualDensity.compact,
            onPressed: onMakeCorrect,
            icon: const Icon(Icons.radio_button_unchecked, size: 19),
            color: BrandColors.muted,
          );
    final removeAction = canRemove
        ? IconButton(
            tooltip: 'Remove option $label',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: BrandColors.muted,
          )
        : const SizedBox(width: 8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF4F4F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFFE5E7EB) : Colors.transparent,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 480
            ? Column(
                children: [
                  Row(
                    children: [
                      marker,
                      const SizedBox(width: 9),
                      Expanded(child: optionField),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [correctAction, removeAction],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  marker,
                  const SizedBox(width: 9),
                  Expanded(child: optionField),
                  const SizedBox(width: 6),
                  correctAction,
                  removeAction,
                ],
              ),
      ),
    );
  }
}
