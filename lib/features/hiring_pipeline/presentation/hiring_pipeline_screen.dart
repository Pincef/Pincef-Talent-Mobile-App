import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';

import '../../../core/entitlements/module_codes.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/data/models/user_model.dart';
import '../data/models/hiring_pipeline_model.dart';
import '../data/hiring_pipline_repository.dart';
import '../application/hiring_pipeline_provider.dart';
import 'edit_pipeline_screen.dart';
import 'pipeline_theme.dart';

class HiringPipelineScreen extends ConsumerStatefulWidget {
  const HiringPipelineScreen({super.key});

  @override
  ConsumerState<HiringPipelineScreen> createState() =>
      _HiringPipelineScreenState();
}

class _HiringPipelineScreenState extends ConsumerState<HiringPipelineScreen> {
  static const _pageSize = 5;
  static const _filters = ['All', 'Active', 'Draft', 'Locked'];

  final _search = TextEditingController();
  String _filter = 'All';
  String _sort = 'Last updated';
  int _page = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  List<HiringPipeline> _filtered(List<HiringPipeline> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((p) {
      final okFilter = _filter == 'All' || p.state == _filter.toUpperCase();
      final haystack =
          '${p.name} ${p.code} ${p.stages.map((s) => s.name).join(' ')}'
              .toLowerCase();
      return okFilter && (q.isEmpty || haystack.contains(q));
    }).toList();
    if (_sort == 'Name A–Z') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  // --------------------------------------------------------------- actions

  Future<void> _openEditor(
      {HiringPipeline? pipeline, bool readOnly = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PipelineEditorScreen(pipeline: pipeline, readOnly: readOnly),
      ),
    );
    if (saved == true && mounted) {
      showSnack(context, 'Pipeline saved.', kind: AppToastKind.success);
    }
  }

  void _create(List<HiringPipeline> all) {
    final unavailable = _createDisabledReason(all);
    if (unavailable != null) {
      _upgrade(unavailable);
      return;
    }
    _openEditor();
  }

  String? _createDisabledReason(List<HiringPipeline> all) {
    final user = ref.read(authProvider).user;
    final endpointCaps = ref.read(pipelineCapabilitiesProvider).value;
    if (!_allowsCustomPipelines(user, endpointCaps)) {
      return "Your current plan doesn't support custom hiring pipelines.";
    }

    final maxCustom =
        (user?.capabilities['maxCustomPipelines'] as num?)?.toInt() ??
            endpointCaps?.maxCustomPipelines;
    final customCount = all.where((p) => !p.isSystemStandard).length;
    if (maxCustom != null && customCount >= maxCustom) {
      return 'Your plan allows up to $maxCustom custom pipeline(s). '
          'Delete one or upgrade to add more.';
    }
    return null;
  }

  bool _allowsCustomPipelines(
    UserModel? user,
    PipelineCapabilities? endpointCaps,
  ) {
    // The explicit capability is the most specific entitlement. It must win
    // over a stale or incomplete module list from /auth/me.
    final explicit = user?.capabilities['allowsCustomPipelines'];
    if (explicit is bool) return explicit;
    if (endpointCaps != null) return endpointCaps.allowsCustomPipelines;
    // Backward compatibility for older responses without capabilities.
    if (user?.modules != null) {
      return user!.hasModule(ModuleCodes.hiringPipeline) ||
          user.hasModule(ModuleCodes.jobPipelineCustom);
    }
    return true;
  }

  void _upgrade(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upgrade required'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _export(List<HiringPipeline> all) async {
    if (all.isEmpty) {
      showSnack(context, 'No workflows to export yet.');
      return;
    }
    final json = const JsonEncoder.withIndent('  ')
        .convert(all.map((p) => p.toExportJson()).toList());
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      showSnack(
        context,
        '${all.length} workflows copied to clipboard as JSON.',
        kind: AppToastKind.success,
      );
    }
  }

  Future<void> _duplicate(HiringPipeline p) async {
    const suffix = ' (Copy)';
    final base = p.name.length > 80 - suffix.length
        ? p.name.substring(0, 80 - suffix.length)
        : p.name;
    try {
      await ref
          .read(pipelinesProvider.notifier)
          .create(name: '$base$suffix', stages: p.stages);
      if (mounted) {
        showSnack(context, 'Pipeline duplicated.', kind: AppToastKind.success);
      }
    } on PipelineApiException catch (e) {
      if (mounted) showSnack(context, e.message, kind: AppToastKind.error);
    }
  }

  Future<void> _delete(HiringPipeline p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete pipeline?'),
        content: Text('"${p.name}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: PT.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(pipelinesProvider.notifier).delete(p.id);
      if (mounted) {
        showSnack(context, 'Pipeline deleted.', kind: AppToastKind.success);
      }
    } on PipelineApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message,
            kind: AppToastKind.error); // e.g. 409 "used by N active jobs"
      }
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    ref.watch(pipelineCapabilitiesProvider);
    ref.watch(authProvider);
    final async = ref.watch(pipelinesProvider);
    final all = async.value ?? const <HiringPipeline>[];

    return Scaffold(
      backgroundColor: PT.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: PT.orange,
          onRefresh: () => ref.read(pipelinesProvider.notifier).refresh(),
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 760;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 28, 22, compact ? 16 : 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(compact, all),
                        const SizedBox(height: 18),
                        if (!async.hasValue && async.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: PT.orange)),
                          )
                        else if (!async.hasValue && async.hasError)
                          _errorState(async.error)
                        else
                          ..._body(all, compact),
                      ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _header(bool compact, List<HiringPipeline> all) {
    final createDisabledReason = _createDisabledReason(all);
    final exportBtn = _actionButton(
        'Export Workflows', Icons.download_outlined, false, () => _export(all));
    final createBtn = _actionButton(
        'Create Pipeline', Icons.add, true, () => _create(all),
        enabled: createDisabledReason == null, tooltip: createDisabledReason);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'TALENT OPERATIONS',
              style: TextStyle(color: PT.orange, fontWeight: FontWeight.w700),
            ),
            TextSpan(
                text: '  /  Workflow Architecture',
                style: TextStyle(color: PT.muted)),
          ]),
          style: TextStyle(fontSize: 10, letterSpacing: .6)),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hiring Pipeline',
                style: TextStyle(
                    color: PT.ink, fontWeight: FontWeight.w800, fontSize: 26)),
            SizedBox(height: 6),
            Text(
              'Create and manage customized hiring workflows for your recruitment process. '
              'Standardize candidate progression across cross-functional teams.',
              style: TextStyle(color: PT.muted, fontSize: 12, height: 1.45),
            ),
          ]),
        ),
        if (!compact) ...[
          const SizedBox(width: 20),
          exportBtn,
          const SizedBox(width: 10),
          createBtn
        ],
      ]),
      if (compact) ...[
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: exportBtn),
          const SizedBox(width: 10),
          Expanded(child: createBtn),
        ]),
      ],
    ]);
  }

  List<Widget> _body(List<HiringPipeline> all, bool compact) {
    final visible = _filtered(all);
    final pages = (visible.length / _pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final items = visible.skip(page * _pageSize).take(_pageSize).toList();
    final start = visible.isEmpty ? 0 : page * _pageSize + 1;
    final end = page * _pageSize + items.length;

    return [
      _metrics(all),
      const SizedBox(height: 14),
      _toolbar(compact, all),
      const SizedBox(height: 12),
      if (items.isEmpty)
        _emptyState(all.isEmpty)
      else
        for (final p in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PipelineCard(
              pipeline: p,
              onView: () => _openEditor(pipeline: p, readOnly: true),
              onEdit: () => p.isLocked
                  ? showSnack(
                      context,
                      p.isSystemStandard
                          ? "The standard pipeline can't be edited. Duplicate it to customise."
                          : 'This workflow is locked while candidates are active in it.')
                  : _openEditor(pipeline: p),
              onDuplicate: () => _duplicate(p),
              onDelete: () => _delete(p),
            ),
          ),
      const SizedBox(height: 6),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, color: PT.orange, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Assessments are linked per job, keeping your pipeline workflows cleanly reusable across departments.',
            style: TextStyle(color: PT.muted, fontSize: 11, height: 1.4),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Text('Showing $start–$end of ${visible.length} pipelines',
              style: const TextStyle(color: PT.muted, fontSize: 10.5)),
        ),
        if (pages > 1) _pager(page, pages),
      ]),
    ];
  }

  // --------------------------------------------------------------- metrics

  Widget _metrics(List<HiringPipeline> all) {
    final active = all.where((p) => p.state == 'ACTIVE').length;
    final draft = all.where((p) => p.state == 'DRAFT').length;
    final locked = all.where((p) => p.state == 'LOCKED').length;
    final jobs = all.fold<int>(0, (sum, p) => sum + p.jobCount);

    final cards = [
      _Metric('ACTIVE PIPELINES', '$active', 'workflows live', Icons.circle,
          PT.orange,
          dot: true),
      _Metric('DRAFT TEMPLATES', '$draft', 'in construction', Icons.circle,
          const Color(0xFF8791A4),
          dot: true),
      _Metric('LOCKED STAGES', '$locked', 'active candidates',
          Icons.lock_outline, PT.muted),
      _Metric('TOTAL LINKED JOBS', '$jobs', 'requisitions mapped',
          Icons.work_outline, PT.orange),
    ];

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 700 ? 4 : 2;
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final c in cards) SizedBox(width: w, child: c),
      ]);
    });
  }

  // -------------------------------------------------------------- toolbar

  Widget _toolbar(bool compact, List<HiringPipeline> all) {
    int count(String label) => label == 'All'
        ? all.length
        : all.where((p) => p.state == label.toUpperCase()).length;

    final chips = Row(mainAxisSize: MainAxisSize.min, children: [
      for (final label in _filters)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ChoiceChip(
            label: Text('$label (${count(label)})',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _filter == label ? PT.ink : PT.muted,
                )),
            selected: _filter == label,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFEDF3FE),
            side: BorderSide(
                color: _filter == label
                    ? const Color(0xFFBDD0F4)
                    : Colors.transparent),
            onSelected: (_) => setState(() {
              _filter = label;
              _page = 0;
            }),
          ),
        ),
    ]);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: cardBox(),
      child: compact
          ? Column(children: [
              _searchField(),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, child: chips)),
                const SizedBox(width: 6),
                _sortMenu(),
              ]),
            ])
          : Row(children: [
              SizedBox(width: 330, child: _searchField()),
              const SizedBox(width: 12),
              chips,
              const Spacer(),
              _sortMenu(),
            ]),
    );
  }

  Widget _searchField() => SizedBox(
        height: 38,
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() => _page = 0),
          style: const TextStyle(fontSize: 12),
          decoration: pipelineInput(
            hint: 'Search pipelines, roles, or stages...',
            prefix: const Icon(Icons.search, size: 18, color: PT.muted),
          ).copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        ),
      );

  Widget _sortMenu() => DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sort,
          isDense: true,
          icon:
              const Icon(Icons.keyboard_arrow_down, size: 16, color: PT.muted),
          style: const TextStyle(
              fontSize: 10.5, color: PT.ink, fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(
                value: 'Last updated', child: Text('Sort: Last updated')),
            DropdownMenuItem(value: 'Name A–Z', child: Text('Sort: Name A–Z')),
          ],
          onChanged: (v) => setState(() {
            _sort = v ?? _sort;
            _page = 0;
          }),
        ),
      );

  Widget _actionButton(
          String label, IconData icon, bool primary, VoidCallback onTap,
          {bool enabled = true, String? tooltip}) =>
      Tooltip(
        message: tooltip ?? '',
        child: SizedBox(
          height: 38,
          child: FilledButton.icon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, size: 16),
            label: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: primary ? PT.orange : Colors.white,
              foregroundColor: primary ? Colors.white : PT.ink,
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              disabledForegroundColor: PT.muted,
              elevation: 0,
              side: primary ? null : const BorderSide(color: PT.line),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );

  Widget _pager(int page, int pages) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        for (var i = 0; i < pages; i++)
          GestureDetector(
            onTap: () => setState(() => _page = i),
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == page ? PT.orange : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: i == page ? PT.orange : PT.line),
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: i == page ? Colors.white : PT.ink,
                  )),
            ),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed:
              page < pages - 1 ? () => setState(() => _page = page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
      ]);

  Widget _emptyState(bool noPipelinesAtAll) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(34),
        decoration: cardBox(radius: 12),
        child: Column(children: [
          const Icon(Icons.account_tree_outlined, color: PT.muted, size: 30),
          const SizedBox(height: 8),
          Text(
              noPipelinesAtAll
                  ? 'No pipelines yet'
                  : 'No pipelines match your search',
              style:
                  const TextStyle(color: PT.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              noPipelinesAtAll
                  ? 'Create your first workflow to get started.'
                  : 'Try another name, role or stage.',
              style: const TextStyle(color: PT.muted, fontSize: 12)),
        ]),
      );

  Widget _errorState(Object? error) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: cardBox(radius: 12),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, color: PT.muted, size: 30),
          const SizedBox(height: 8),
          const Text("Couldn't load pipelines",
              style: TextStyle(color: PT.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
              error is PipelineApiException
                  ? error.message
                  : 'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PT.muted, fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.invalidate(pipelinesProvider),
            child: const Text('Retry'),
          ),
        ]),
      );
}

// ---------------------------------------------------------------------------

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.caption, this.icon, this.color,
      {this.dot = false});
  final String title, value, caption;
  final IconData icon;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: cardBox(radius: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 8.5,
                      color: PT.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .3)),
            ),
            Icon(icon, size: dot ? 7 : 12, color: color),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 21,
                    color: PT.ink,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: PT.muted)),
            ),
          ]),
        ]),
      );
}

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({
    required this.pipeline,
    required this.onView,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final HiringPipeline pipeline;
  final VoidCallback onView, onEdit, onDuplicate, onDelete;

  static IconData _iconFor(HiringPipeline p) {
    if (p.isSystemStandard) return Icons.workspace_premium_outlined;
    final n = p.name.toLowerCase();
    if (n.contains('design')) return Icons.design_services_outlined;
    if (n.contains('engineer') || n.contains('dev') || n.contains('tech')) {
      return Icons.code_rounded;
    }
    if (n.contains('graduate') || n.contains('intern')) {
      return Icons.school_outlined;
    }
    if (n.contains('sales')) return Icons.trending_up_rounded;
    return Icons.account_tree_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final p = pipeline;
    final stateColor = switch (p.state) {
      'ACTIVE' => PT.green,
      'DRAFT' => PT.muted,
      _ => PT.slate,
    };

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 430;

      final menu = PopupMenuButton<String>(
        tooltip: 'More options',
        icon: const Icon(Icons.more_vert, size: 18, color: PT.muted),
        padding: EdgeInsets.zero,
        onSelected: (v) => v == 'dup' ? onDuplicate() : onDelete(),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
          PopupMenuItem(
            value: 'del',
            enabled: !p.isSystemStandard,
            child: const Text('Delete', style: TextStyle(color: PT.danger)),
          ),
        ],
      );

      final view = _smallButton('View', Icons.visibility_outlined, onView,
          expand: !wide);
      final edit = _smallButton(
          'Edit', p.isLocked ? Icons.lock_outline : Icons.edit_outlined, onEdit,
          muted: p.isLocked, expand: !wide);

      return Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
        decoration: cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: PT.softBlue, borderRadius: BorderRadius.circular(8)),
              child: Icon(_iconFor(p), color: PT.blue, size: 17),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                          spacing: 7,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(p.name,
                                style: const TextStyle(
                                    color: PT.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5)),
                            StatusBadge(p.state, stateColor,
                                icon: p.isLocked ? Icons.lock_outline : null),
                            Text(p.code,
                                style: const TextStyle(
                                    color: PT.muted,
                                    fontSize: 9,
                                    fontFamily: 'monospace')),
                          ]),
                      const SizedBox(height: 5),
                      Wrap(spacing: 11, runSpacing: 3, children: [
                        _meta(
                            Icons.layers_outlined, '${p.stages.length} Stages'),
                        if (p.candidateCount > 0)
                          _meta(Icons.people_outline,
                              'Candidates active in pipeline')
                        else if (p.isSystemStandard)
                          _meta(Icons.shield_outlined, 'System default')
                        else
                          _meta(Icons.work_outline,
                              '${p.jobCount} ${p.jobCount == 1 ? 'active job' : 'active jobs'}'),
                        _meta(
                            Icons.schedule, 'Updated ${timeAgo(p.updatedAt)}'),
                      ]),
                    ]),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 8),
              view,
              const SizedBox(width: 6),
              edit,
              const SizedBox(width: 2),
            ],
            SizedBox(width: 30, height: 30, child: menu),
          ]),
          if (!wide) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Row(children: [
                Expanded(child: view),
                const SizedBox(width: 8),
                Expanded(child: edit)
              ]),
            ),
          ],
          const SizedBox(height: 11),
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < p.stages.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(Icons.arrow_forward,
                          size: 11, color: Color(0xFFA0A9B8)),
                    ),
                  _stageChip(i, p.stages[i], i == p.stages.length - 1),
                ],
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _meta(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: PT.muted),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: PT.muted, fontSize: 10)),
      ]);

  Widget _smallButton(String text, IconData icon, VoidCallback onTap,
          {bool muted = false, bool expand = false}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 12),
        label: Text(text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: muted ? PT.muted : PT.ink,
          side: const BorderSide(color: PT.line),
          minimumSize: Size(expand ? double.infinity : 0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      );

  Widget _stageChip(int index, PipelineStage stage, bool last) {
    final fg = last ? Colors.white : PT.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: last ? PT.orange : PT.soft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text((index + 1).toString().padLeft(2, '0'),
            style: TextStyle(
              color: last ? Colors.white70 : PT.orange,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(width: 5),
        Text(stage.name,
            style: TextStyle(
                color: fg, fontSize: 9.5, fontWeight: FontWeight.w600)),
        if (isAssessmentType(stage.type)) ...[
          const SizedBox(width: 4),
          Icon(Icons.assignment_outlined,
              size: 10, color: last ? Colors.white : PT.muted),
        ],
      ]),
    );
  }
}
