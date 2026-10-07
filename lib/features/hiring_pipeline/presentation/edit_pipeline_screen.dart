import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';

import '../../../core/entitlements/module_codes.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/data/models/user_model.dart';
import '../data/models/hiring_pipeline_model.dart';
import '../data/hiring_pipline_repository.dart';
import '../application/hiring_pipeline_provider.dart';
import 'pipeline_theme.dart';

/// At or above this width the stage config opens as a side panel;
/// below it, as a bottom sheet (mobile).
const double _kSidePanelBreakpoint = 1000;

class _DraftStage {
  _DraftStage({
    int? id,
    required this.type,
    required this.name,
    this.isRequired = true,
    this.description = '',
    this.assessmentMode = 'ai',
    this.passingScore = 75,
    this.durationMins = 60,
  }) : id = id ?? _next++;

  static int _next = 0;

  /// Stable identity for reordering / selection (never sent to the API).
  final int id;
  String type;
  String name;
  bool isRequired;
  String description;
  String assessmentMode;
  int passingScore;
  int durationMins;

  /// Same `id`, so an edited copy can be swapped back into the list.
  _DraftStage copy() => _DraftStage(
        id: id,
        type: type,
        name: name,
        isRequired: isRequired,
        description: description,
        assessmentMode: assessmentMode,
        passingScore: passingScore,
        durationMins: durationMins,
      );
}

class PipelineEditorScreen extends ConsumerStatefulWidget {
  const PipelineEditorScreen({super.key, this.pipeline, this.readOnly = false});

  /// null → create a new pipeline.
  final HiringPipeline? pipeline;
  final bool readOnly;

  @override
  ConsumerState<PipelineEditorScreen> createState() =>
      _PipelineEditorScreenState();
}

class _PipelineEditorScreenState extends ConsumerState<PipelineEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late List<_DraftStage> _stages;
  int? _selectedId;
  bool _reorder = true;
  bool _saving = false;
  bool _dirty = false;

  bool get _readOnly => widget.readOnly || (widget.pipeline?.isLocked ?? false);
  bool get _isNew => widget.pipeline == null;

  @override
  void initState() {
    super.initState();
    final p = widget.pipeline;
    _name = TextEditingController(text: p?.name ?? '');
    _desc = TextEditingController(text: p?.description ?? '');
    _stages = p == null
        ? [
            _DraftStage(
              type: 'APPLIED',
              name: stageMetaFor('APPLIED').label,
              description: stageMetaFor('APPLIED').blurb,
            ),
          ]
        : [
            for (final s in p.stages)
              _DraftStage(
                type: s.type,
                name: s.name,
                isRequired: s.isRequired,
                description: s.description.isEmpty
                    ? stageMetaFor(s.type).blurb
                    : s.description,
                assessmentMode: s.assessmentMode,
                passingScore: s.passingScore,
                durationMins: s.durationMins,
              ),
          ];
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- stages

  List<({String key, bool locked})> _catalogItems(PipelineCapabilities? caps) {
    final user = ref.read(authProvider).user;
    final keys = <String>[...kStageTypeMeta.keys];
    for (final t in caps?.allowedStageTypes ?? const <String>[]) {
      if (!keys.contains(t.toUpperCase())) keys.add(t.toUpperCase());
    }
    return [
      for (final k in keys)
        (
          key: k,
          locked:
              (caps != null && !caps.allows(k)) || !_stageModuleAllows(user, k)
        )
    ];
  }

  bool _stageModuleAllows(UserModel? user, String type) {
    // Older API responses may omit modules; the capabilities endpoint remains
    // the fallback in that case. An explicitly empty module list is restrictive.
    if (user == null || user.modules == null) return true;
    switch (type.toUpperCase()) {
      case 'INTERVIEW':
        return user.hasModule(ModuleCodes.hiringStageInterview);
      case 'ASSESSMENT':
        return user.hasModule(ModuleCodes.hiringStageAssessment);
      default:
        return true;
    }
  }

  void _addStage(String key, {required bool locked}) {
    if (_readOnly) return;
    if (locked) {
      showSnack(context,
          "Your plan doesn't include this stage type. Upgrade to use it.",
          kind: AppToastKind.error);
      return;
    }
    if (_stages.length >= 20) {
      showSnack(context, 'A pipeline can have at most 20 stages.',
          kind: AppToastKind.error);
      return;
    }
    final meta = stageMetaFor(key);
    setState(() {
      _stages.add(
          _DraftStage(type: key, name: meta.label, description: meta.blurb));
      _dirty = true;
    });
  }

  Future<void> _pickStage(PipelineCapabilities? caps) async {
    if (_readOnly) return;
    final items = _catalogItems(caps);
    final picked = await showModalBottomSheet<({String key, bool locked})>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Add hiring stage',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: PT.ink)),
          ),
          for (final it in items)
            ListTile(
              leading: Icon(stageMetaFor(it.key).icon,
                  color: it.locked ? PT.muted : PT.blue),
              title: Text(stageMetaFor(it.key).label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: it.locked ? PT.muted : PT.ink)),
              subtitle: Text(stageMetaFor(it.key).blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
              trailing: it.locked
                  ? const Icon(Icons.lock_outline, size: 16, color: PT.muted)
                  : null,
              onTap: () => Navigator.pop(ctx, it),
            ),
        ]),
      ),
    );
    if (picked != null) _addStage(picked.key, locked: picked.locked);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final s = _stages.removeAt(oldIndex);
      _stages.insert(newIndex, s);
      _dirty = true;
    });
  }

  void _removeStage(_DraftStage s) {
    if (_stages.length <= 1) {
      showSnack(context, 'A pipeline needs at least one stage.',
          kind: AppToastKind.error);
      return;
    }
    setState(() {
      _stages.removeWhere((e) => e.id == s.id);
      if (_selectedId == s.id) _selectedId = null;
      _dirty = true;
    });
  }

  void _applyStage(_DraftStage edited) {
    final i = _stages.indexWhere((e) => e.id == edited.id);
    if (i == -1) return;
    setState(() {
      _stages[i]
        ..name = edited.name
        ..isRequired = edited.isRequired
        ..assessmentMode = edited.assessmentMode
        ..passingScore = edited.passingScore
        ..durationMins = edited.durationMins;
      _dirty = true;
    });
  }

  Future<void> _configure(_DraftStage s) async {
    setState(() => _selectedId = s.id);
    final wide = MediaQuery.sizeOf(context).width >= _kSidePanelBreakpoint;
    if (wide) return; // side panel renders in build()

    final index = _stages.indexWhere((e) => e.id == s.id);
    final result = await showModalBottomSheet<_DraftStage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _StageConfigPanel(
          stage: s.copy(),
          index: index,
          readOnly: _readOnly,
          onCancel: () => Navigator.pop(ctx),
          onSave: (d) => Navigator.pop(ctx, d),
        ),
      ),
    );
    if (result != null) _applyStage(result);
    if (mounted) setState(() => _selectedId = null);
  }

  // ------------------------------------------------------------------ save

  Future<void> _save(String status) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Give your pipeline a name.',
          kind: AppToastKind.error);
      return;
    }
    if (name.length > 80) {
      showSnack(context, 'Pipeline name must be 80 characters or fewer.',
          kind: AppToastKind.error);
      return;
    }
    if (_stages.isEmpty) {
      showSnack(context, 'Add at least one stage.', kind: AppToastKind.error);
      return;
    }
    if (_stages.any((s) => s.name.trim().isEmpty)) {
      showSnack(context, 'Every stage needs a name.', kind: AppToastKind.error);
      return;
    }

    final caps = ref.read(pipelineCapabilitiesProvider).value;
    final stages = [
      for (var i = 0; i < _stages.length; i++)
        PipelineStage(
          type: caps?.resolve(_stages[i].type) ?? _stages[i].type,
          name: _stages[i].name.trim(),
          order: i,
          isRequired: _stages[i].isRequired,
          description: _stages[i].description,
          assessmentMode: _stages[i].assessmentMode,
          passingScore: _stages[i].passingScore,
          durationMins: _stages[i].durationMins,
        ),
    ];

    setState(() => _saving = true);
    try {
      final notifier = ref.read(pipelinesProvider.notifier);
      if (_isNew) {
        await notifier.create(
          name: name,
          stages: stages,
          description: _desc.text.trim(),
          status: status,
        );
      } else {
        await notifier.updatePipeline(
          widget.pipeline!.id,
          name: name,
          stages: stages,
          description: _desc.text.trim(),
          status: status,
        );
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      Navigator.of(context).pop(true);
    } on PipelineApiException catch (e) {
      if (mounted) showSnack(context, e.message, kind: AppToastKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content:
            const Text('Your unsaved changes to this pipeline will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: PT.danger)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _discard() async {
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final endpointCaps = ref.watch(pipelineCapabilitiesProvider).value;
    final loginCapabilities = ref.watch(authProvider).user?.capabilities;
    final caps = endpointCaps ??
        (loginCapabilities == null || loginCapabilities.isEmpty
            ? null
            : PipelineCapabilities.fromEntitlements(loginCapabilities));
    final wide = MediaQuery.sizeOf(context).width >= _kSidePanelBreakpoint;
    final selected = _stages.where((s) => s.id == _selectedId).firstOrNull;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _breadcrumb(),
            const SizedBox(height: 12),
            _titleBlock(),
            const SizedBox(height: 16),
            _coreCard(caps),
            const SizedBox(height: 22),
            _stagesHeader(),
            const SizedBox(height: 12),
            _stageList(),
            const SizedBox(height: 4),
            _addStageButton(caps),
            const SizedBox(height: 14),
            _catalogCard(caps),
          ]),
        ),
      ),
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: PT.bg,
        body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: content),
            if (wide && selected != null)
              Container(
                width: 350,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: PT.line)),
                ),
                child: _StageConfigPanel(
                  key: ValueKey(selected.id),
                  stage: selected.copy(),
                  index: _stages.indexWhere((e) => e.id == selected.id),
                  readOnly: _readOnly,
                  onCancel: () => setState(() => _selectedId = null),
                  onSave: (d) {
                    _applyStage(d);
                    setState(() => _selectedId = null);
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _breadcrumb() => Row(children: [
        InkWell(
          onTap: _discard,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_ios_new, size: 12, color: PT.muted),
              SizedBox(width: 4),
              Text('Pipelines',
                  style: TextStyle(fontSize: 11, color: PT.muted)),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('/', style: TextStyle(fontSize: 11, color: PT.muted)),
        ),
        Flexible(
          child: Text(_isNew ? 'New Pipeline' : widget.pipeline!.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, color: PT.ink, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        StatusBadge(_isNew ? 'DRAFT' : widget.pipeline!.state,
            _isNew ? PT.orange : PT.slate),
      ]);

  Widget _titleBlock() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _isNew
              ? 'Create Hiring Pipeline'
              : (_readOnly ? 'Hiring Pipeline' : 'Edit Hiring Pipeline'),
          style: const TextStyle(
              color: PT.ink,
              fontWeight: FontWeight.w800,
              fontSize: 25,
              height: 1.15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure the sequential stages candidates will progress through for associated jobs. '
          'Automated gates, scorecard rubrics, and assessment rules trigger synchronously.',
          style: TextStyle(color: PT.muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 14),
        if (_readOnly)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: PT.soft, borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 14, color: PT.muted),
              SizedBox(width: 8),
              Expanded(
                child: Text('This workflow is read-only.',
                    style: TextStyle(fontSize: 11, color: PT.muted)),
              ),
            ]),
          )
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save('draft'),
                  icon: const Icon(Icons.save_outlined, size: 15),
                  label: const Text('Save as Draft',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PT.ink,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: PT.line),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _discard,
                  style: TextButton.styleFrom(
                      foregroundColor: PT.muted,
                      minimumSize: const Size(0, 38)),
                  child: const Text('Discard',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save('active'),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.rocket_launch_outlined, size: 15),
                  label: const Text('Save & Publish Pipeline',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: PT.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
      ]);

  Widget _coreCard(PipelineCapabilities? caps) => Container(
        padding: const EdgeInsets.all(14),
        decoration: cardBox(radius: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune, size: 15, color: PT.orange),
            const SizedBox(width: 7),
            const Expanded(
              child: Text('Requisition Core Parameters',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: PT.ink)),
            ),
            if (caps != null && caps.plan.isNotEmpty)
              StatusBadge('${caps.plan.toUpperCase()} PLAN', PT.blue),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Expanded(child: _FieldLabel('Pipeline Name *')),
            Text('ID: ${widget.pipeline?.code ?? 'assigned on save'}',
                style: const TextStyle(
                    fontSize: 9.5, color: PT.muted, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            enabled: !_readOnly,
            maxLength: 80,
            onChanged: (_) => _dirty = true,
            style: const TextStyle(fontSize: 13),
            decoration: pipelineInput(hint: 'e.g. Product Designer Hiring')
                .copyWith(counterText: ''),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Description & Objective Scope'),
          const SizedBox(height: 6),
          TextField(
            controller: _desc,
            enabled: !_readOnly,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => _dirty = true,
            style: const TextStyle(fontSize: 13, height: 1.4),
            decoration: pipelineInput(hint: 'What is this workflow for?'),
          ),
        ]),
      );

  Widget _stagesHeader() => Row(children: [
        const Text('Hiring Stages',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: PT.ink)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: PT.soft, borderRadius: BorderRadius.circular(6)),
          child: Text(
              '${_stages.length} Linear Gate${_stages.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: PT.slate)),
        ),
        const Spacer(),
        if (!_readOnly)
          TextButton.icon(
            onPressed: () => setState(() => _reorder = !_reorder),
            icon: Icon(_reorder ? Icons.check : Icons.swap_vert, size: 14),
            label: Text(_reorder ? 'Done' : 'Reorder',
                style: const TextStyle(fontSize: 11)),
            style: TextButton.styleFrom(
                foregroundColor: PT.ink, visualDensity: VisualDensity.compact),
          ),
      ]);

  Widget _stageList() => Stack(children: [
        Positioned(
          left: 13,
          top: 18,
          bottom: 18,
          child: Container(width: 1.5, color: PT.line),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _stages.length,
          onReorder: _onReorder,
          proxyDecorator: (child, _, __) =>
              Material(color: Colors.transparent, child: child),
          itemBuilder: (context, i) => _stageTile(i, _stages[i]),
        ),
      ]);

  Widget _stageTile(int i, _DraftStage s) {
    final selected = _selectedId == s.id;
    final meta = stageMetaFor(s.type);
    final showHandle = _reorder && !_readOnly;

    return Padding(
      key: ValueKey(s.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? PT.orange : Colors.white,
            border:
                Border.all(color: selected ? PT.orange : PT.line, width: 1.5),
          ),
          child: Text((i + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : PT.orange,
              )),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _configure(s),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
              decoration: cardBox(
                border: selected ? PT.blue : PT.line,
                width: selected ? 1.6 : 1,
                radius: 10,
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showHandle)
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(0, 2, 6, 2),
                      child: Icon(Icons.drag_indicator,
                          size: 18, color: Color(0xFFA0A9B8)),
                    ),
                  )
                else
                  const SizedBox(width: 6),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(s.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: PT.ink)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: PT.softBlue,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(meta.label,
                                    style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                        color: PT.blue)),
                              ),
                              Text(s.isRequired ? 'Required' : 'Optional',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: s.isRequired ? PT.danger : PT.muted,
                                  )),
                            ]),
                        if (s.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(s.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: PT.muted,
                                  height: 1.35)),
                        ],
                        if (selected) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: PT.orange,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 10, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('In Configuration',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                          ),
                        ],
                        if (isAssessmentType(s.type)) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: PT.softOrange,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: const Color(0xFFFFD9BF)),
                            ),
                            child: Text(
                              'Assessment attached per-job requisition  ·  Passing: ${s.passingScore}% | ${s.durationMins} Min',
                              style: const TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFFB4470A),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ]),
                ),
                if (!_readOnly)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert,
                          size: 17, color: PT.muted),
                      onSelected: (v) =>
                          v == 'cfg' ? _configure(s) : _removeStage(s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'cfg', child: Text('Configure')),
                        PopupMenuItem(
                            value: 'rm',
                            child: Text('Remove',
                                style: TextStyle(color: PT.danger))),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _addStageButton(PipelineCapabilities? caps) {
    if (_readOnly) return const SizedBox.shrink();
    return InkWell(
      onTap: () => _pickStage(caps),
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        painter: const _DashedBorderPainter(color: Color(0xFFBDD0F4)),
        child: Container(
          width: double.infinity,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: PT.softBlue.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline, size: 16, color: PT.blue),
            SizedBox(width: 7),
            Text('Add Hiring Stage',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: PT.blue)),
          ]),
        ),
      ),
    );
  }

  Widget _catalogCard(PipelineCapabilities? caps) {
    if (_readOnly) return const SizedBox.shrink();
    final items = _catalogItems(caps);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PT.soft.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PT.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(
            child: Text('STAGE CATALOG LIBRARY',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: PT.muted,
                    letterSpacing: .5)),
          ),
          Text('Tap a template to append',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600, color: PT.orange)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final it in items)
            InkWell(
              onTap: () => _addStage(it.key, locked: it.locked),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: PT.line),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(stageMetaFor(it.key).icon,
                      size: 13, color: it.locked ? PT.muted : PT.blue),
                  const SizedBox(width: 6),
                  Text(stageMetaFor(it.key).label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: it.locked ? PT.muted : PT.ink,
                      )),
                  if (it.locked) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.lock_outline, size: 11, color: PT.muted),
                  ],
                ]),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: PT.ink));
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color}) : radius = 10;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ---------------------------------------------------------------------------
// Stage configuration (side panel on wide screens, bottom sheet on mobile)
// ---------------------------------------------------------------------------

class _StageConfigPanel extends StatefulWidget {
  const _StageConfigPanel({
    super.key,
    required this.stage,
    required this.index,
    required this.readOnly,
    required this.onSave,
    required this.onCancel,
  });

  final _DraftStage stage;
  final int index;
  final bool readOnly;
  final ValueChanged<_DraftStage> onSave;
  final VoidCallback onCancel;

  @override
  State<_StageConfigPanel> createState() => _StageConfigPanelState();
}

class _StageConfigPanelState extends State<_StageConfigPanel> {
  late final TextEditingController _name =
      TextEditingController(text: widget.stage.name);
  late final TextEditingController _score =
      TextEditingController(text: '${widget.stage.passingScore}');
  late final TextEditingController _mins =
      TextEditingController(text: '${widget.stage.durationMins}');
  late String _assessMode = widget.stage.assessmentMode;
  late bool _required = widget.stage.isRequired;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _score.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => _error = 'Stage name must be 1–60 characters.');
      return;
    }
    final s = widget.stage
      ..name = name
      ..isRequired = _required
      ..assessmentMode = _assessMode
      ..passingScore = (int.tryParse(_score.text) ?? 75).clamp(0, 100).toInt()
      ..durationMins = (int.tryParse(_mins.text) ?? 60).clamp(1, 600).toInt();
    widget.onSave(s);
  }

  @override
  Widget build(BuildContext context) {
    final meta = stageMetaFor(widget.stage.type);
    final assessment = isAssessmentType(widget.stage.type);

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: PT.orange, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.tune, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stage Configuration · Stage ${widget.index + 1}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: PT.ink)),
                      const SizedBox(height: 2),
                      Text('Gate Type: ${meta.label}',
                          style:
                              const TextStyle(fontSize: 10.5, color: PT.muted)),
                    ]),
              ),
              IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 20)),
            ]),
          ),
          const Divider(height: 1, color: PT.line),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Custom Stage Name'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _name,
                      enabled: !widget.readOnly,
                      maxLength: 60,
                      style: const TextStyle(fontSize: 13),
                      decoration: pipelineInput(errorText: _error)
                          .copyWith(counterText: ''),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 5),
                    Text(
                        'Replaces the generic "${meta.label}" label in the candidate portal.',
                        style: const TextStyle(
                            fontSize: 10,
                            color: PT.muted,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeThumbColor: PT.orange,
                      title: const Text('Required stage',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PT.ink)),
                      subtitle: const Text(
                          'Candidates must pass this gate to progress.',
                          style: TextStyle(fontSize: 10.5, color: PT.muted)),
                      value: _required,
                      onChanged: widget.readOnly
                          ? null
                          : (v) => setState(() => _required = v),
                    ),
                    if (assessment) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PT.softBlue,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCFDDF7)),
                        ),
                        child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.link, size: 15, color: PT.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Dynamic Requisition Binding',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                              color: PT.ink)),
                                      SizedBox(height: 3),
                                      Text(
                                        'Assessments are associated per job. This stage establishes the gate; choose the '
                                        'specific test when connecting this pipeline to a job requisition.',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: PT.muted,
                                            height: 1.4),
                                      ),
                                    ]),
                              ),
                            ]),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Assessment Creation Mode'),
                      const SizedBox(height: 8),
                      _modeOption('ai', 'AI-Assisted Creation',
                          'Generate tailored rubrics, scenario briefs and challenge prompts based on role level.',
                          pro: true),
                      _modeOption('manual', 'Manual Creation',
                          'Author your own questions, upload links, or customise rubric matrices manually.'),
                      _modeOption('auto', 'Automatic Generation',
                          'Instantly populate from the platform\'s library of assessment templates.'),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                            child: _numberField('Passing score (%)', _score)),
                        const SizedBox(width: 10),
                        Expanded(child: _numberField('Duration (min)', _mins)),
                      ]),
                    ],
                  ]),
            ),
          ),
          const Divider(height: 1, color: PT.line),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PT.ink,
                    side: const BorderSide(color: PT.line),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(widget.readOnly ? 'Close' : 'Cancel'),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: PT.orange,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Stage Changes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
          ),
        ]);
  }

  Widget _numberField(String label, TextEditingController c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: PT.muted)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          enabled: !widget.readOnly,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: pipelineInput(),
        ),
      ]);

  Widget _modeOption(String value, String title, String subtitle,
      {bool pro = false}) {
    final sel = _assessMode == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            widget.readOnly ? null : () => setState(() => _assessMode = value),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? PT.softOrange : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? PT.orange : PT.line, width: sel ? 1.5 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: sel ? PT.orange : PT.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: PT.ink)),
                          if (pro)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                  color: PT.ink,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('PRO TIER',
                                  style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                        ]),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10.5, color: PT.muted, height: 1.4)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
