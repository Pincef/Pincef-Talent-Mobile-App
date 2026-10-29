import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/messages/application/messages_provider.dart'
    show
        messagesRepositoryProvider,
        selectedMessageThreadProvider,
        messageThreadsProvider;
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/jobs/application/application_provider.dart';
import 'package:talentbridge/features/jobs/data/models/application_model.dart';
import '../../application/job_management_provider.dart';
import '../../application/candidate_ranking_provider.dart';
import '../../data/models/candidate_ranking_model.dart';

/// AI Candidate Ranking — reached from the "AI Candidate Ranking" chip on
/// JobCandidatesScreen's AI tools bar. Always ranks every current
/// applicant for the job; there's no candidate-selection step here (see
/// job_candidates_screen.dart's _runBulkAction — it deliberately ignores
/// the card-selection state for this one action).
///
class AiCandidateRankingScreen extends ConsumerStatefulWidget {
  const AiCandidateRankingScreen({
    super.key,
    required this.jobId,
    required this.originRoute,
    required this.originLabel,
  });

  final String jobId;
  final String originRoute;
  final String originLabel;

  @override
  ConsumerState<AiCandidateRankingScreen> createState() =>
      _AiCandidateRankingScreenState();
}

class _AiCandidateRankingScreenState
    extends ConsumerState<AiCandidateRankingScreen> {
  bool _retrying = false;

  Future<void> _retryFailed() async {
    setState(() => _retrying = true);
    try {
      final count = await ref
          .read(candidateRankingRepositoryProvider)
          .retryFailedJobRanking(widget.jobId);
      ref.invalidate(candidateRankingProvider(widget.jobId));
      if (mounted) {
        AppToast.success(
            context, 'Retrying AI review for $count candidate(s).');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, 'Could not retry AI review: $error');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = widget.jobId;
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final jobTitle =
        jobAsync.maybeWhen(data: (job) => job.title, orElse: () => 'this role');
    final ranking = ref.watch(candidateRankingProvider(jobId));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Breadcrumb(
                  jobTitle: jobTitle,
                  originLabel: widget.originLabel,
                  onBack: () => context.go(
                        widget.originRoute == '/jobs/${widget.jobId}/candidates'
                            ? '${widget.originRoute}?showCandidates=true'
                            : widget.originRoute,
                      )),
              const SizedBox(height: 14),
              _Header(
                isWide: isWide,
                jobTitle: jobTitle,
                candidateCount: ranking.valueOrNull?.totalRanked,
                onExport: () => _notImplemented(context, 'Export Rankings'),
                onFilter: () => _notImplemented(context, 'Filter'),
              ),
              const SizedBox(height: 22),
              ranking.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _RankingError(
                  onRetry: () =>
                      ref.invalidate(candidateRankingProvider(jobId)),
                ),
                data: (result) => result.isLocked
                    ? const _AiResultsUnavailable()
                    : (result.aiStatus == 'queued' ||
                                result.aiStatus == 'running') &&
                            result.entries.isEmpty
                        ? _RankingProcessing(
                            analyzed: result.analyzedCount,
                            total: result.totalRanked,
                            onRefresh: () =>
                                ref.invalidate(candidateRankingProvider(jobId)),
                          )
                        : (result.aiStatus == 'failed' ||
                                    result.failedCount > 0) &&
                                result.entries.isEmpty
                            ? _RankingFailed(
                                failed: result.failedCount,
                                retrying: _retrying,
                                onRetry: _retryFailed,
                                onRefresh: () => ref.invalidate(
                                    candidateRankingProvider(jobId)),
                              )
                            : result.entries.isEmpty
                                ? _NoRankingsFound(
                                    onRetry: () => ref.invalidate(
                                        candidateRankingProvider(jobId)),
                                    onViewCandidates: () =>
                                        context.go('/jobs/$jobId/candidates'),
                                  )
                                : _RankingBody(
                                    jobId: jobId,
                                    isWide: isWide,
                                    result: result,
                                    retrying: _retrying,
                                    onRetryFailed: _retryFailed,
                                  ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _notImplemented(BuildContext context, String label) {
    AppToast.info(context, '$label is coming soon.');
  }
}

class _RankingProcessing extends StatelessWidget {
  const _RankingProcessing(
      {required this.analyzed, required this.total, required this.onRefresh});

  final int analyzed;
  final int total;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: BrandColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          const Text('AI review is processing candidates',
              style: TextStyle(
                  color: BrandColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            total > 0
                ? '$analyzed of $total candidates analyzed.'
                : 'Preparing candidate analysis.',
            style: const TextStyle(color: BrandColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Refresh results'),
          ),
        ]),
      );
}

class _RankingFailed extends StatelessWidget {
  const _RankingFailed({
    required this.failed,
    required this.retrying,
    required this.onRetry,
    required this.onRefresh,
  });

  final int failed;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFFFD6C7)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          const Icon(Icons.warning_amber_rounded,
              color: BrandColors.orange, size: 30),
          const SizedBox(height: 10),
          const Text('AI review could not finish',
              style: TextStyle(
                  color: BrandColors.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            failed > 0
                ? '$failed candidate analysis(es) failed. You can retry them; completed results will be kept.'
                : 'The AI review stopped before producing results. You can retry the review.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: BrandColors.muted, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            FilledButton.icon(
              onPressed: retrying ? null : onRetry,
              icon: retrying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 15),
              label:
                  Text(retrying ? 'Queueing retry…' : 'Retry failed analyses'),
            ),
            TextButton(
                onPressed: onRefresh, child: const Text('Refresh status')),
          ]),
        ]),
      );
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.jobTitle,
    required this.originLabel,
    required this.onBack,
  });
  final String jobTitle;
  final String originLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onBack,
            child: Text(originLabel,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: BrandColors.muted,
                    fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('/',
                style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
          ),
          Flexible(
            child: Text(jobTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: BrandColors.navy,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isWide,
    required this.jobTitle,
    required this.candidateCount,
    required this.onExport,
    required this.onFilter,
  });

  final bool isWide;
  final String jobTitle;
  final int? candidateCount;
  final VoidCallback onExport;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final subtitle = candidateCount == null
        ? 'Automated rankings use match score, role fit, relevant strengths, and experience.'
        : 'Automated ranking of $candidateCount candidates by match score, role fit, strengths, and experience.';

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isWide ? 460 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Automated Ranking',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11.5, color: BrandColors.muted)),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('Filter', style: TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.navy,
                side: const BorderSide(color: BrandColors.border),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.ios_share, size: 15),
              label: const Text('Export Rankings',
                  style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: BrandColors.navy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RankingBody extends ConsumerStatefulWidget {
  const _RankingBody(
      {required this.jobId,
      required this.isWide,
      required this.result,
      required this.retrying,
      required this.onRetryFailed});

  final String jobId;
  final bool isWide;
  final CandidateRankingResult result;
  final bool retrying;
  final VoidCallback onRetryFailed;

  @override
  ConsumerState<_RankingBody> createState() => _RankingBodyState();
}

class _RankingBodyState extends ConsumerState<_RankingBody> {
  bool _showSummaries = false;

  @override
  void initState() {
    super.initState();
    _showSummaries = !widget.result.rankingEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.failedCount > 0) ...[
          _RankingFailed(
            failed: result.failedCount,
            retrying: widget.retrying,
            onRetry: widget.onRetryFailed,
            onRefresh: () =>
                ref.invalidate(candidateRankingProvider(widget.jobId)),
          ),
          const SizedBox(height: 16),
        ],
        if (result.rankingEnabled) ...[
          _StatsRow(isWide: widget.isWide, result: result),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.leaderboard_outlined),
                label: Text('Automated Ranking'),
              ),
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.summarize_outlined),
                label: Text('Candidate Summaries'),
              ),
            ],
            selected: {_showSummaries},
            onSelectionChanged: (selection) =>
                setState(() => _showSummaries = selection.first),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const Text('AI Candidate Summaries',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy)),
          const SizedBox(height: 8),
        ],
        if (_showSummaries)
          _CandidateSummaryList(
            jobId: widget.jobId,
            entries: result.entries,
            enabled: result.summaryEnabled,
            commonSkill: result.topSkillLabel,
            commonSkillPercent: result.topSkillOverlapPercent,
          )
        else
          _RankingList(
              jobId: widget.jobId,
              isWide: widget.isWide,
              entries: result.entries,
              total: result.totalRanked),
        const SizedBox(height: 20),
        if (!_showSummaries)
          _AutomateWorkflowCard(jobId: widget.jobId, entries: result.entries),
      ],
    );
  }
}

class _CandidateSummaryList extends StatefulWidget {
  const _CandidateSummaryList({
    required this.jobId,
    required this.entries,
    required this.enabled,
    required this.commonSkill,
    required this.commonSkillPercent,
  });

  final String jobId;
  final List<CandidateRankingEntry> entries;
  final bool enabled;
  final String commonSkill;
  final int commonSkillPercent;

  @override
  State<_CandidateSummaryList> createState() => _CandidateSummaryListState();
}

class _CandidateSummaryListState extends State<_CandidateSummaryList> {
  static const _pageSize = 8;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const _SummaryEmptyState(
        title: 'AI summaries are not enabled for this job',
        message:
            'Edit the job and enable AI resume summaries in its AI configuration. Summaries are generated after the application deadline.',
      );
    }

    final summarized = widget.entries
        .where((entry) => entry.resumeSummary != null)
        .toList(growable: false);
    if (summarized.isEmpty) {
      return const _SummaryEmptyState(
        title: 'Candidate summaries are not ready yet',
        message:
            'AI summaries appear here after the post-deadline analysis has completed.',
      );
    }

    final totalPages = (summarized.length / _pageSize).ceil();
    if (_page >= totalPages) _page = totalPages - 1;
    final start = _page * _pageSize;
    final pageItems = summarized.skip(start).take(_pageSize);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _summaryMetric('Summaries generated', '${summarized.length}'),
            if (widget.commonSkill != '—')
              _summaryMetric(
                'Most common AI-identified skill',
                '${widget.commonSkill} · ${widget.commonSkillPercent}% of summaries',
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final entry in pageItems)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CandidateSummaryCard(
            entry: entry,
            onReview: () => context
                .push('/jobs/${widget.jobId}/candidates/${entry.candidateId}'),
          ),
        ),
      Row(children: [
        Text(
            'Showing ${start + 1}-${start + pageItems.length} of ${summarized.length}',
            style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${_page + 1} / $totalPages',
            style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
        IconButton(
          tooltip: 'Next page',
          onPressed:
              _page + 1 < totalPages ? () => setState(() => _page++) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    ]);
  }

  Widget _summaryMetric(String label, String value) => SizedBox(
        width: 260,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.muted,
                  letterSpacing: .3)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy)),
        ]),
      );
}

class _CandidateSummaryCard extends StatelessWidget {
  const _CandidateSummaryCard({required this.entry, required this.onReview});
  final CandidateRankingEntry entry;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final summary = entry.resumeSummary ?? const <String, dynamic>{};
    final executive = summary['executiveSummary']?.toString().trim() ?? '';
    final achievements = (summary['topAchievements'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final skills = (summary['skills'] as List? ?? const [])
        .whereType<Map>()
        .map((skill) => Map<String, dynamic>.from(skill))
        .toList();
    final competencies = (summary['competencies'] as List? ?? const [])
        .whereType<String>()
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (entry.rank > 0)
            _RankBadge(rank: entry.rank, level: entry.fitLevel)
          else
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFFFF0E8),
              child:
                  Icon(Icons.auto_awesome, size: 15, color: BrandColors.orange),
            ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: BrandColors.navy)),
              Text(
                  entry.rank > 0
                      ? 'AI match ${entry.score}% · ${entry.fitLabel}'
                      : 'AI-generated resume summary',
                  style:
                      const TextStyle(fontSize: 11, color: BrandColors.muted)),
            ]),
          ),
          TextButton(onPressed: onReview, child: const Text('View profile')),
        ]),
        const Divider(height: 22),
        if (executive.isNotEmpty) ...[
          const Text('EXECUTIVE SUMMARY', style: _summaryLabelStyle),
          const SizedBox(height: 5),
          Text(executive,
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: BrandColors.navy)),
        ],
        if (achievements.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('TOP ACHIEVEMENTS', style: _summaryLabelStyle),
          const SizedBox(height: 5),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: BrandColors.orange),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(achievement,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            color: BrandColors.navy))),
              ]),
            ),
        ],
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('RELEVANT SKILLS', style: _summaryLabelStyle),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final skill in skills)
              Chip(
                label: Text(
                    '${skill['name'] ?? 'Skill'} · ${skill['level'] ?? 'intermediate'}'),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: const Color(0xFFF3F5F8),
              ),
          ]),
        ],
        if (competencies.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('COMPETENCIES', style: _summaryLabelStyle),
          const SizedBox(height: 5),
          Text(competencies.join(' · '),
              style: const TextStyle(
                  fontSize: 11.5, height: 1.4, color: BrandColors.muted)),
        ],
      ]),
    );
  }

  static const _summaryLabelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      color: BrandColors.muted,
      letterSpacing: .4);
}

class _SummaryEmptyState extends StatelessWidget {
  const _SummaryEmptyState({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(children: [
          const Icon(Icons.summarize_outlined,
              size: 30, color: BrandColors.orange),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: BrandColors.navy)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.45, color: BrandColors.muted)),
        ]),
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.isWide, required this.result});
  final bool isWide;
  final CandidateRankingResult result;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        icon: Icons.workspace_premium_outlined,
        label: 'TOP TIER MATCHES',
        value: '${result.topTierCount}',
        sub: '${result.totalRanked} candidates scored',
        color: const Color(0xFF16A34A),
      ),
      _StatCard(
        icon: Icons.speed_outlined,
        label: 'AVG. MATCH SCORE',
        value: '${result.avgMatchScore.round()}%',
        sub: 'Across all ${result.totalRanked} applicants',
        color: BrandColors.orange,
      ),
      if (result.summaryEnabled)
        _StatCard(
          icon: Icons.hub_outlined,
          label: 'MOST COMMON AI SKILL',
          value: result.topSkillLabel,
          sub: '${result.topSkillOverlapPercent}% of AI summaries mention',
          color: const Color(0xFF6366F1),
        ),
    ];

    if (!isWide) {
      return Column(children: [
        for (final c in cards)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
      ]);
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.muted,
                          letterSpacing: .3)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: BrandColors.navy)),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 9.5, color: BrandColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Table-style layout on wide screens (matches the mockup); stacked cards
/// on narrow ones — same responsive pattern job_candidates_screen.dart
/// uses elsewhere in this feature. Paginated client-side since the backend
/// returns the whole computed ranking in one shot (nothing to page
/// server-side for a result that's never stored).
class _RankingList extends ConsumerStatefulWidget {
  const _RankingList(
      {required this.jobId,
      required this.isWide,
      required this.entries,
      required this.total});

  final String jobId;
  final bool isWide;
  final List<CandidateRankingEntry> entries;
  final int total;

  @override
  ConsumerState<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends ConsumerState<_RankingList> {
  static const _pageSize = 10;
  int _page = 0;
  bool _reordering = false;
  bool _savingOrder = false;
  List<CandidateRankingEntry>? _draftOrder;

  List<CandidateRankingEntry> get _orderedEntries =>
      _draftOrder ?? widget.entries;

  bool get _canMessage =>
      ref.read(authProvider).user?.capabilities['allowsCandidateMessaging'] ==
          true ||
      ref.read(authProvider).user?.hasModule('hiring.candidate.messaging') ==
          true;

  Future<void> _message(CandidateRankingEntry entry) async {
    if (!_canMessage) {
      AppToast.info(context,
          'Candidate messaging is available on Pro and Business plans.');
      return;
    }
    try {
      final conversationId = await ref
          .read(messagesRepositoryProvider)
          .startConversationForApplication(entry.applicationId);
      if (!mounted) return;
      ref.invalidate(messageThreadsProvider);
      ref.read(selectedMessageThreadProvider.notifier).state = conversationId;
      context.go('/messages');
    } catch (e) {
      if (mounted) AppToast.error(context, "Couldn't start a conversation: $e");
    }
  }

  Future<void> _shortlist(CandidateRankingEntry entry) async {
    try {
      final emailSent = await ref
          .read(applicationsRepositoryProvider)
          .updateApplicationStatus(
            entry.applicationId,
            ApplicationBackendStatus.shortlisted,
          );
      if (!mounted) return;
      ref.invalidate(candidateRankingProvider(widget.jobId));
      if (emailSent) {
        AppToast.success(context, '${entry.name} shortlisted and notified.');
      } else {
        AppToast.info(context,
            '${entry.name} shortlisted. The status email could not be delivered.');
      }
    } catch (e) {
      if (mounted) AppToast.error(context, "Couldn't shortlist candidate: $e");
    }
  }

  void _beginReordering() {
    setState(() {
      _draftOrder = [...widget.entries];
      _reordering = true;
      _page = 0;
    });
  }

  Future<void> _saveOrder() async {
    final entries = _orderedEntries;
    setState(() => _savingOrder = true);
    try {
      await ref.read(candidateRankingRepositoryProvider).saveJobRankingOrder(
            widget.jobId,
            entries.map((entry) => entry.applicationId).toList(),
          );
      if (!mounted) return;
      ref.invalidate(candidateRankingProvider(widget.jobId));
      setState(() {
        _draftOrder = null;
        _reordering = false;
      });
      AppToast.success(context, 'Candidate ranking order saved.');
    } catch (e) {
      if (mounted) AppToast.error(context, "Couldn't save ranking order: $e");
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  void _cancelReordering() => setState(() {
        _draftOrder = null;
        _reordering = false;
      });

  @override
  Widget build(BuildContext context) {
    final entries = _orderedEntries;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, entries.length);
    final pageItems = entries.sublist(start.clamp(0, entries.length), end);
    final totalPages = (entries.length / _pageSize).ceil().clamp(1, 999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                const Text('Candidate Ranking List',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                if (_reordering) ...[
                  TextButton(
                    onPressed: _savingOrder ? null : _cancelReordering,
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _savingOrder ? null : _saveOrder,
                    child: Text(_savingOrder ? 'Saving…' : 'Save order'),
                  ),
                ] else ...[
                  const _LegendDot(
                      color: Color(0xFF16A34A), label: 'High Match'),
                  const _LegendDot(
                      color: BrandColors.orange, label: 'Medium Match'),
                  OutlinedButton.icon(
                    onPressed:
                        widget.entries.length < 2 ? null : _beginReordering,
                    icon: const Icon(Icons.drag_handle, size: 15),
                    label: const Text('Reorder'),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: BrandColors.border),
          if (_reordering)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: entries.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _draftOrder!.removeAt(oldIndex);
                  _draftOrder!.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  key: ValueKey(entry.applicationId),
                  leading: SizedBox(
                    width: 32,
                    child: Text('${index + 1}'.padLeft(2, '0'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                  ),
                  title: Text(entry.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                  subtitle: Text('${entry.score}% match · ${entry.fitLabel}'),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_indicator,
                        color: BrandColors.muted),
                  ),
                );
              },
            )
          else ...[
            if (widget.isWide) _tableHeader(),
            for (final entry in pageItems)
              widget.isWide ? _tableRow(entry) : _stackedCard(entry),
          ],
          if (!_reordering)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: Row(
                children: [
                  Text(
                      'Showing ${entries.isEmpty ? 0 : start + 1}-$end of ${widget.total} candidates',
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.muted)),
                  const Spacer(),
                  IconButton(
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  Text('${_page + 1} / $totalPages',
                      style: const TextStyle(
                          fontSize: 11, color: BrandColors.muted)),
                  IconButton(
                    onPressed: _page < totalPages - 1
                        ? () => setState(() => _page++)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        color: const Color(0xFFFAFAFB),
        child: const Row(
          children: [
            SizedBox(width: 32, child: Text('RANK', style: _headerStyle)),
            SizedBox(width: 12),
            Expanded(flex: 3, child: Text('CANDIDATE', style: _headerStyle)),
            Expanded(flex: 1, child: Text('SCORE', style: _headerStyle)),
            Expanded(
                flex: 4,
                child: Text('AI INSIGHTS & EXPLANATION', style: _headerStyle)),
            Expanded(flex: 2, child: Text('EXPERIENCE', style: _headerStyle)),
            SizedBox(width: 100, child: Text('ACTION', style: _headerStyle)),
          ],
        ),
      );

  static const _headerStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      color: BrandColors.muted,
      letterSpacing: .3);

  Widget _tableRow(CandidateRankingEntry entry) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: BrandColors.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: _RankBadge(rank: entry.rank, level: entry.fitLevel),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _EntryAvatar(name: entry.name, url: entry.avatarUrl),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.navy)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text('${entry.score}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _colorForLevel(entry.fitLevel))),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.fitLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _colorForLevel(entry.fitLevel))),
                    const SizedBox(height: 2),
                    Text(entry.insight,
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: BrandColors.muted,
                            height: 1.35)),
                    if (entry.strengths.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text('Strengths: ${entry.strengths.join(', ')}',
                          style: const TextStyle(
                              fontSize: 9.5, color: BrandColors.navy)),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.experienceLabel,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                  if (entry.companiesLabel.isNotEmpty)
                    Text(entry.companiesLabel,
                        style: const TextStyle(
                            fontSize: 9.5, color: BrandColors.muted)),
                ],
              ),
            ),
            SizedBox(
              width: 136,
              child: _RowActions(
                onReview: () => context.push(
                    '/jobs/${widget.jobId}/candidates/${entry.candidateId}'),
                onMessage: () => _message(entry),
                onShortlist: entry.applicationStatus == 'submitted'
                    ? () => _shortlist(entry)
                    : null,
                canMessage: _canMessage,
              ),
            ),
          ],
        ),
      );

  Widget _stackedCard(CandidateRankingEntry entry) => Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RankBadge(rank: entry.rank, level: entry.fitLevel),
                const SizedBox(width: 10),
                _EntryAvatar(name: entry.name, url: entry.avatarUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                ),
                Text('${entry.score}%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _colorForLevel(entry.fitLevel))),
              ],
            ),
            const SizedBox(height: 10),
            Text(entry.fitLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _colorForLevel(entry.fitLevel))),
            const SizedBox(height: 2),
            Text(entry.insight,
                style: const TextStyle(
                    fontSize: 11, color: BrandColors.muted, height: 1.4)),
            if (entry.strengths.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text('Strengths: ${entry.strengths.join(', ')}',
                  style:
                      const TextStyle(fontSize: 10.5, color: BrandColors.navy)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(entry.experienceLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.navy)),
                if (entry.companiesLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· ${entry.companiesLabel}',
                      style: const TextStyle(
                          fontSize: 10.5, color: BrandColors.muted)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            _RowActions(
              onReview: () => context.push(
                  '/jobs/${widget.jobId}/candidates/${entry.candidateId}'),
              onMessage: () => _message(entry),
              onShortlist: entry.applicationStatus == 'submitted'
                  ? () => _shortlist(entry)
                  : null,
              canMessage: _canMessage,
              expand: true,
            ),
          ],
        ),
      );

  Color _colorForLevel(RankingFitLevel level) => switch (level) {
        RankingFitLevel.high => const Color(0xFF16A34A),
        RankingFitLevel.medium => BrandColors.orange,
        RankingFitLevel.low => BrandColors.muted,
      };
}

class _RowActions extends StatelessWidget {
  const _RowActions(
      {required this.onReview,
      required this.onMessage,
      required this.canMessage,
      this.onShortlist,
      this.expand = false});
  final VoidCallback onReview;
  final VoidCallback onMessage;
  final bool canMessage;
  final VoidCallback? onShortlist;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final reviewButton = SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onReview,
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.orange,
          side: const BorderSide(color: BrandColors.orange),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Review',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
      ),
    );
    final messageButton = SizedBox(
      width: 30,
      height: 30,
      child: OutlinedButton(
        onPressed: onMessage,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: BrandColors.navy,
          side: const BorderSide(color: BrandColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Icon(canMessage ? Icons.chat_bubble_outline : Icons.lock_outline,
            size: 14),
      ),
    );
    final shortlistButton = Tooltip(
      message: 'Shortlist candidate',
      child: SizedBox(
        width: 30,
        height: 30,
        child: OutlinedButton(
          onPressed: onShortlist,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: const Color(0xFF0A8F68),
            side: const BorderSide(color: Color(0xFFB7E5D7)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Icon(Icons.playlist_add_check, size: 15),
        ),
      ),
    );

    if (expand) {
      return Row(children: [
        Expanded(child: reviewButton),
        const SizedBox(width: 8),
        if (onShortlist != null) ...[
          shortlistButton,
          const SizedBox(width: 8),
        ],
        messageButton
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      reviewButton,
      const SizedBox(width: 4),
      if (onShortlist != null) ...[
        shortlistButton,
        const SizedBox(width: 4),
      ],
      messageButton,
    ]);
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.level});
  final int rank;
  final RankingFitLevel level;

  Color get _color => switch (level) {
        RankingFitLevel.high => const Color(0xFF16A34A),
        RankingFitLevel.medium => BrandColors.orange,
        RankingFitLevel.low => BrandColors.muted,
      };

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: _color.withValues(alpha: .14), shape: BoxShape.circle),
        child: Text(rank.toString().padLeft(2, '0'),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: _color)),
      );
}

class _EntryAvatar extends StatelessWidget {
  const _EntryAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();
    return CircleAvatar(
      radius: 15,
      backgroundColor: BrandColors.navy.withValues(alpha: .12),
      backgroundImage:
          (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty)
          ? Text(initials,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy))
          : null,
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  color: BrandColors.muted,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _AutomateWorkflowCard extends StatelessWidget {
  const _AutomateWorkflowCard({required this.jobId, required this.entries});
  final String jobId;
  final List<CandidateRankingEntry> entries;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: BrandColors.navy, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Next Hiring Steps',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
                if (entries.isNotEmpty)
                  SizedBox(
                    height: 26,
                    width: 26 + (entries.length > 1 ? 14 : 0),
                    child: Stack(
                      children: [
                        for (var i = 0; i < entries.length.clamp(0, 2); i++)
                          Positioned(
                            left: i * 14.0,
                            child: _EntryAvatar(
                                name: entries[i].name,
                                url: entries[i].avatarUrl),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const _WorkflowStep(label: 'Review AI-ranked candidates'),
            const _WorkflowStep(
                label: 'Invite shortlisted candidates to assessment'),
            const _WorkflowStep(
                label: 'Schedule interviews and track outcomes'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/jobs/$jobId/candidates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Manage Hiring Pipeline',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF34D399)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ],
        ),
      );
}

class _RankingError extends StatelessWidget {
  const _RankingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 32, color: BrandColors.muted),
            const SizedBox(height: 10),
            const Text('Rankings are unavailable right now',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BrandColors.navy)),
            const SizedBox(height: 4),
            const Text(
                'We couldn’t load AI rankings. Please try again in a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: BrandColors.muted)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.navy,
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
}

class _NoRankingsFound extends StatelessWidget {
  const _NoRankingsFound({
    required this.onRetry,
    required this.onViewCandidates,
  });

  final VoidCallback onRetry;
  final VoidCallback onViewCandidates;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.query_stats_outlined,
                size: 34, color: BrandColors.orange),
            const SizedBox(height: 12),
            const Text('No rankings found yet',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BrandColors.navy)),
            const SizedBox(height: 6),
            const Text(
              'There are no ranked applicants for this job yet. Check back after candidates apply, or review the candidate list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: BrandColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onViewCandidates,
                  child: const Text('View candidates'),
                ),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Refresh rankings'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _AiResultsUnavailable extends StatelessWidget {
  const _AiResultsUnavailable();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_outlined,
                  size: 34, color: BrandColors.orange),
              SizedBox(height: 10),
              Text('AI results are not available for this job yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: BrandColors.navy)),
              SizedBox(height: 4),
              Text('Enable ranking or summaries in the job workflow settings.',
                  style: TextStyle(fontSize: 12, color: BrandColors.muted)),
            ],
          ),
        ),
      );
}
