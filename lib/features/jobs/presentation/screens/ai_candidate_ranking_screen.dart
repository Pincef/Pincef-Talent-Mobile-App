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
import '../../application/job_management_provider.dart';
import '../../application/candidate_ranking_provider.dart';
import '../../data/models/candidate_ranking_model.dart';

/// AI Candidate Ranking — reached from the "AI Candidate Ranking" chip on
/// JobCandidatesScreen's AI tools bar. Always ranks every current
/// applicant for the job; there's no candidate-selection step here (see
/// job_candidates_screen.dart's _runBulkAction — it deliberately ignores
/// the card-selection state for this one action).
///
/// Feature-gating: this is meant to sit behind the company's payment plan
/// (PlanType on company.model.ts) — that check is bypassed for now per
/// request, so the screen is reachable by everyone. Search this file for
/// "PLAN GATE" for the one spot to wire that in later.
class AiCandidateRankingScreen extends ConsumerWidget {
  const AiCandidateRankingScreen({super.key, required this.jobId});

  final String jobId;

  // PLAN GATE: flip this (or read it from the company's PlanType) once
  // billing exists. Nothing else in this screen needs to change — every
  // call site below already guards on this single flag.
  static const bool _featureUnlocked = true;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_featureUnlocked) {
      return const _UpgradeRequired();
    }

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
                  jobTitle: jobTitle, onBackToJobs: () => context.go('/jobs')),
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
                  message: '$e',
                  onRetry: () =>
                      ref.invalidate(candidateRankingProvider(jobId)),
                ),
                data: (result) =>
                    _RankingBody(jobId: jobId, isWide: isWide, result: result),
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

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.jobTitle, required this.onBackToJobs});
  final String jobTitle;
  final VoidCallback onBackToJobs;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onBackToJobs,
            child: const Text('Active Jobs',
                style: TextStyle(
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
        ? 'Processing candidates against role requirements using TalentBridge AI...'
        : 'Processed $candidateCount candidates against role requirements using TalentBridge AI';

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
              const Text('AI Candidate Ranking',
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

class _RankingBody extends ConsumerWidget {
  const _RankingBody(
      {required this.jobId, required this.isWide, required this.result});

  final String jobId;
  final bool isWide;
  final CandidateRankingResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsRow(isWide: isWide, result: result),
        const SizedBox(height: 20),
        _RankingList(
            jobId: jobId,
            isWide: isWide,
            entries: result.entries,
            total: result.totalRanked),
        const SizedBox(height: 20),
        isWide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _ReasoningCard(result: result)),
                    const SizedBox(width: 16),
                    Expanded(
                        flex: 2,
                        child: _AutomateWorkflowCard(entries: result.entries)),
                  ],
                ),
              )
            : Column(
                children: [
                  _ReasoningCard(result: result),
                  const SizedBox(height: 16),
                  _AutomateWorkflowCard(entries: result.entries),
                ],
              ),
      ],
    );
  }
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
      _StatCard(
        icon: Icons.hub_outlined,
        label: 'SKILL OVERLAP',
        value: result.topSkillLabel,
        sub: '${result.topSkillOverlapPercent}% of top matches possess',
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

  Future<void> _message(CandidateRankingEntry entry) async {
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

  @override
  Widget build(BuildContext context) {
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.entries.length);
    final pageItems =
        widget.entries.sublist(start.clamp(0, widget.entries.length), end);
    final totalPages = (widget.entries.length / _pageSize).ceil().clamp(1, 999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Text('Candidate Ranking List',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                Spacer(),
                _LegendDot(color: Color(0xFF16A34A), label: 'High Match'),
                SizedBox(width: 12),
                _LegendDot(color: BrandColors.orange, label: 'Medium Match'),
              ],
            ),
          ),
          const Divider(height: 1, color: BrandColors.border),
          if (widget.isWide) _tableHeader(),
          for (final entry in pageItems)
            widget.isWide ? _tableRow(entry) : _stackedCard(entry),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Row(
              children: [
                Text(
                    'Showing ${widget.entries.isEmpty ? 0 : start + 1}-$end of ${widget.total} candidates',
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
              width: 100,
              child: _RowActions(
                onReview: () => context.push(
                    '/jobs/${widget.jobId}/candidates/${entry.candidateId}'),
                onMessage: () => _message(entry),
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
      {required this.onReview, required this.onMessage, this.expand = false});
  final VoidCallback onReview;
  final VoidCallback onMessage;
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
        child: const Icon(Icons.chat_bubble_outline, size: 14),
      ),
    );

    if (expand) {
      return Row(children: [
        Expanded(child: reviewButton),
        const SizedBox(width: 8),
        messageButton
      ]);
    }
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: [reviewButton, const SizedBox(width: 6), messageButton]);
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

class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({required this.result});
  final CandidateRankingResult result;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Talent Match Reasoning',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const Text('Global ranking algorithm synthesis',
                style: TextStyle(fontSize: 10.5, color: BrandColors.muted)),
            const SizedBox(height: 14),
            if (result.marketReasoning.isNotEmpty)
              _ReasoningCallout(
                title: 'Market Competitive Edge',
                body: result.marketReasoning.first,
                color: const Color(0xFF16A34A),
                icon: Icons.trending_up,
              ),
            if (result.marketReasoning.isNotEmpty &&
                result.skillGapReasoning.isNotEmpty)
              const SizedBox(height: 10),
            if (result.skillGapReasoning.isNotEmpty)
              _ReasoningCallout(
                title: 'Skill Gap Identified',
                body: result.skillGapReasoning.first,
                color: BrandColors.orange,
                icon: Icons.warning_amber_outlined,
              ),
            if (result.marketReasoning.isEmpty &&
                result.skillGapReasoning.isEmpty)
              const Text('No additional reasoning returned for this ranking.',
                  style: TextStyle(fontSize: 11, color: BrandColors.muted)),
          ],
        ),
      );
}

class _ReasoningCallout extends StatelessWidget {
  const _ReasoningCallout(
      {required this.title,
      required this.body,
      required this.color,
      required this.icon});
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(9)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          fontSize: 10.5,
                          color: BrandColors.muted,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Static checklist for now — "Activate Workflow" has no backend behind it
/// yet, same status as the other un-implemented AI tools on
/// job_candidates_screen.dart.
class _AutomateWorkflowCard extends StatelessWidget {
  const _AutomateWorkflowCard({required this.entries});
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
                  child: Text('Automate Workflow',
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
            const _WorkflowStep(label: 'Technical Assessment'),
            const _WorkflowStep(label: 'Interview Email'),
            const _WorkflowStep(label: 'Calendar Reminder'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => AppToast.info(
                    context, 'Workflow automation is coming soon.'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Activate Workflow',
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
  const _RankingError({required this.message, required this.onRetry});
  final String message;
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
            const Icon(Icons.error_outline, size: 30, color: Color(0xFFDC2626)),
            const SizedBox(height: 10),
            const Text("Couldn't run candidate ranking",
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: BrandColors.navy)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
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

class _UpgradeRequired extends StatelessWidget {
  const _UpgradeRequired();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 34, color: BrandColors.orange),
              SizedBox(height: 10),
              Text('AI Candidate Ranking is a paid feature',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: BrandColors.navy)),
              SizedBox(height: 4),
              Text('Upgrade your plan to unlock AI-ranked candidate lists.',
                  style: TextStyle(fontSize: 12, color: BrandColors.muted)),
            ],
          ),
        ),
      );
}
