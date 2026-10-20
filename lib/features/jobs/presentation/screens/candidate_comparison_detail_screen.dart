import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../interviews/application/interview_provider.dart';
import '../../../interviews/presentation/schedule_interview_sheet_screen.dart';
import '../../application/application_provider.dart';
import '../../application/candidate_ranking_provider.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/application_model.dart';
import '../../data/models/candidate_ranking_model.dart';

/// Side-by-side view backed by this job's applicants and any completed AI
/// ranking. Profile/application comparison remains available before ranking.
class CandidateComparisonDetailScreen extends ConsumerWidget {
  const CandidateComparisonDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(jobId));
    final applicants = ref.watch(jobApplicantsProvider(jobId));
    final ranking = ref.watch(candidateRankingProvider(jobId));
    final candidateByApplication = {
      for (final applicant in applicants.applications) applicant.id: applicant,
    };
    final rankedApplicants = <JobApplicantSummary>[];
    for (final entry
        in ranking.valueOrNull?.entries ?? const <CandidateRankingEntry>[]) {
      final applicant = candidateByApplication[entry.applicationId];
      if (applicant != null && !rankedApplicants.contains(applicant)) {
        rankedApplicants.add(applicant);
      }
    }
    final ordered = rankedApplicants.isNotEmpty
        ? rankedApplicants
        : [...applicants.applications]
      ..sort((a, b) {
        final aScore = a.aiScore ?? -1;
        final bScore = b.aiScore ?? -1;
        if (aScore != bScore) return bScore.compareTo(aScore);
        final aShortlisted =
            a.status == ApplicationBackendStatus.shortlisted ? 1 : 0;
        final bShortlisted =
            b.status == ApplicationBackendStatus.shortlisted ? 1 : 0;
        if (aShortlisted != bShortlisted) {
          return bShortlisted.compareTo(aShortlisted);
        }
        return a.appliedAt.compareTo(b.appliedAt);
      });
    final compared = ordered.take(3).toList(growable: false);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      return SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: job.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ComparisonError(
                message: 'Could not load this job: $error',
                onBack: () => context.go('/candidate-comparison'),
              ),
              data: (jobData) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ComparisonDetailHeader(
                    jobTitle: jobData.title,
                    jobId: jobId,
                    onBack: () => context.go('/candidate-comparison'),
                  ),
                  const SizedBox(height: 22),
                  if (applicants.isLoading && applicants.applications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (applicants.error != null &&
                      applicants.applications.isEmpty)
                    _ComparisonError(
                      message: applicants.error!,
                      onBack: () => context.go('/candidate-comparison'),
                    )
                  else if (compared.isEmpty)
                    _NoApplicants(
                      onViewApplicants: () =>
                          context.go('/jobs/$jobId/candidates'),
                    )
                  else ...[
                    _CandidateComparisonCards(
                      applicants: compared,
                      ranking: ranking.valueOrNull,
                      jobId: jobId,
                    ),
                    if (ranking.isLoading && ranking.valueOrNull == null) ...[
                      const SizedBox(height: 12),
                      const _RankingNotice(
                        message: 'Loading available AI ranking details…',
                      ),
                    ] else if (ranking.hasError ||
                        (ranking.valueOrNull?.entries.isEmpty ?? true)) ...[
                      const SizedBox(height: 12),
                      _RankingNotice(
                        message: ranking.valueOrNull?.isLocked == true
                            ? 'AI ranking is not enabled for this workspace. You can still compare candidate profiles and application stages below.'
                            : 'AI scores and explanations appear after the job’s application deadline and ranking process. You can compare applicant profiles and application stages now.',
                      ),
                    ],
                    const SizedBox(height: 18),
                    _ComparisonInsights(
                      applicants: compared,
                      ranking: ranking.valueOrNull,
                      requiredSkills: jobData.requiredSkills,
                      wide: wide,
                    ),
                    const SizedBox(height: 18),
                    _ComparisonTable(
                      applicants: compared,
                      ranking: ranking.valueOrNull,
                    ),
                    const SizedBox(height: 24),
                    if (applicants.hasMore)
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: applicants.isLoadingMore
                              ? null
                              : () => ref
                                  .read(jobApplicantsProvider(jobId).notifier)
                                  .loadMore(),
                          icon: applicants.isLoadingMore
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.expand_more),
                          label: Text(applicants.isLoadingMore
                              ? 'Loading candidates…'
                              : 'Load more candidates'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ComparisonDetailHeader extends StatelessWidget {
  const _ComparisonDetailHeader({
    required this.jobTitle,
    required this.jobId,
    required this.onBack,
  });
  final String jobTitle;
  final String jobId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onBack,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back, size: 15, color: BrandColors.muted),
                    SizedBox(width: 6),
                    Text('Candidate Comparison',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.muted)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(jobTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.navy)),
                const SizedBox(height: 4),
                Text('Shortlist comparison · Job ID: $jobId',
                    style: const TextStyle(
                        fontSize: 13, color: BrandColors.muted)),
              ],
            ),
          ),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () =>
                  AppToast.info(context, 'Share report is coming soon.'),
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share Report'),
            ),
            OutlinedButton.icon(
              onPressed: () => AppToast.info(context, 'Export is coming soon.'),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export PDF'),
            ),
          ]),
        ],
      );
}

class _CandidateComparisonCards extends ConsumerStatefulWidget {
  const _CandidateComparisonCards({
    required this.applicants,
    required this.ranking,
    required this.jobId,
  });
  final List<JobApplicantSummary> applicants;
  final CandidateRankingResult? ranking;
  final String jobId;

  @override
  ConsumerState<_CandidateComparisonCards> createState() =>
      _CandidateComparisonCardsState();
}

class _CandidateComparisonCardsState
    extends ConsumerState<_CandidateComparisonCards> {
  final Set<String> _scheduling = {};
  final Set<String> _offering = {};

  Future<void> _schedule(JobApplicantSummary applicant) async {
    setState(() => _scheduling.add(applicant.id));
    try {
      await showScheduleInterview(context, applicationId: applicant.id);
      if (!mounted) return;
      ref.invalidate(jobApplicantsProvider(widget.jobId));
      ref.invalidate(schedulableProvider);
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Could not open interview scheduling: $error');
      }
    } finally {
      if (mounted) setState(() => _scheduling.remove(applicant.id));
    }
  }

  Future<void> _offer(JobApplicantSummary applicant) async {
    setState(() => _offering.add(applicant.id));
    try {
      final emailSent = await ref
          .read(applicationsRepositoryProvider)
          .updateApplicationStatus(
              applicant.id, ApplicationBackendStatus.offered);
      if (!mounted) return;
      ref.invalidate(jobApplicantsProvider(widget.jobId));
      if (emailSent) {
        AppToast.success(context,
            'Offer stage updated and ${applicant.candidate.fullName} was notified.');
      } else {
        AppToast.info(context,
            'Offer stage updated, but the candidate email could not be sent.');
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Could not send the offer update: $error');
      }
    } finally {
      if (mounted) setState(() => _offering.remove(applicant.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesByApplication = {
      for (final entry
          in widget.ranking?.entries ?? const <CandidateRankingEntry>[])
        entry.applicationId: entry,
    };
    final rankedRecommendation = widget.ranking?.entries
        .where((entry) =>
            widget.applicants.any((app) => app.id == entry.applicationId))
        .firstOrNull;
    final scoredApplicants = widget.applicants
        .where((app) =>
            entriesByApplication[app.id]?.score != null || app.aiScore != null)
        .toList()
      ..sort((a, b) => (entriesByApplication[b.id]?.score ?? b.aiScore ?? -1)
          .compareTo(entriesByApplication[a.id]?.score ?? a.aiScore ?? -1));
    final recommendedApplicationId = rankedRecommendation?.applicationId ??
        (scoredApplicants.isEmpty ? null : scoredApplicants.first.id);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1180
          ? 3
          : constraints.maxWidth >= 800
              ? 2
              : 1;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.applicants.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: columns == 1 ? 460 : 448,
        ),
        itemBuilder: (context, index) {
          final applicant = widget.applicants[index];
          final entry = entriesByApplication[applicant.id];
          final score = entry?.score ?? applicant.aiScore;
          return _CandidateCompareCard(
            applicant: applicant,
            entry: entry,
            score: score,
            recommended: applicant.id == recommendedApplicationId,
            scheduling: _scheduling.contains(applicant.id),
            offering: _offering.contains(applicant.id),
            onSchedule: () => _schedule(applicant),
            onOffer: () => _offer(applicant),
          );
        },
      );
    });
  }
}

class _CandidateCompareCard extends StatelessWidget {
  const _CandidateCompareCard({
    required this.applicant,
    required this.entry,
    required this.score,
    required this.recommended,
    required this.scheduling,
    required this.offering,
    required this.onSchedule,
    required this.onOffer,
  });
  final JobApplicantSummary applicant;
  final CandidateRankingEntry? entry;
  final int? score;
  final bool recommended;
  final bool scheduling;
  final bool offering;
  final VoidCallback onSchedule;
  final VoidCallback onOffer;

  bool get _canSchedule =>
      applicant.status == ApplicationBackendStatus.submitted ||
      applicant.status == ApplicationBackendStatus.shortlisted ||
      applicant.status == ApplicationBackendStatus.interviewing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: recommended ? BrandColors.orange : const Color(0xFFE7C9B9),
              width: recommended ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (recommended)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: BrandColors.orange,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('TOP RECOMMENDATION',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3)),
              ),
            ),
          if (recommended) const SizedBox(height: 11),
          Row(children: [
            _ProfileAvatar(applicant: applicant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(applicant.candidate.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 19,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                    const SizedBox(height: 5),
                    _ApplicationStatusBadge(status: applicant.status),
                  ]),
            ),
          ]),
          const SizedBox(height: 13),
          Wrap(spacing: 8, runSpacing: 7, children: [
            _CandidateFact(
              icon: Icons.work_outline,
              text: applicant.candidate.yearsOfExperience == null
                  ? 'Experience not listed'
                  : '${applicant.candidate.yearsOfExperience} years experience',
            ),
            if (applicant.candidate.location?.isNotEmpty == true)
              _CandidateFact(
                  icon: Icons.location_on_outlined,
                  text: applicant.candidate.location!),
          ]),
          if (applicant.candidate.education.isNotEmpty) ...[
            const SizedBox(height: 7),
            _CandidateFact(
                icon: Icons.school_outlined,
                text: applicant.candidate.education.first),
          ],
          const SizedBox(height: 13),
          Row(children: [
            const Expanded(
              child: Text('AI MATCH SCORE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.muted,
                      letterSpacing: .35)),
            ),
            Text(score == null ? 'Pending' : '$score%',
                style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color:
                        recommended ? BrandColors.orange : BrandColors.navy)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score == null ? 0 : score!.clamp(0, 100) / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFE8EEF8),
              valueColor: AlwaysStoppedAnimation<Color>(
                  recommended ? BrandColors.orange : const Color(0xFF59618B)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('CORE STRENGTHS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.muted,
                  letterSpacing: .35)),
          const SizedBox(height: 7),
          _StrengthChips(
              strengths: entry?.strengths.isNotEmpty == true
                  ? entry!.strengths
                  : applicant.candidate.skills.take(4).toList()),
          const SizedBox(height: 10),
          const Text('AI INSIGHT',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.muted,
                  letterSpacing: .35)),
          const SizedBox(height: 4),
          Text(
            entry?.insight.isNotEmpty == true
                ? entry!.insight
                : 'AI rationale will appear after candidate scoring completes.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11, height: 1.4, color: BrandColors.muted),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: scheduling || !_canSchedule ? null : onSchedule,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.orange,
                  side: const BorderSide(color: BrandColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: scheduling
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        _canSchedule
                            ? 'Schedule Interview'
                            : 'Interview unavailable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: offering ||
                        applicant.status == ApplicationBackendStatus.hired ||
                        applicant.status == ApplicationBackendStatus.offered ||
                        applicant.status == ApplicationBackendStatus.rejected
                    ? null
                    : onOffer,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF080D33),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: offering
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        applicant.status == ApplicationBackendStatus.offered
                            ? 'Offer Sent'
                            : applicant.status ==
                                        ApplicationBackendStatus.rejected ||
                                    applicant.status ==
                                        ApplicationBackendStatus.hired
                                ? 'Not available'
                                : 'Send Offer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ]),
      );
}

class _ComparisonInsights extends StatelessWidget {
  const _ComparisonInsights({
    required this.applicants,
    required this.ranking,
    required this.requiredSkills,
    required this.wide,
  });
  final List<JobApplicantSummary> applicants;
  final CandidateRankingResult? ranking;
  final List<String> requiredSkills;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final ranked = ranking?.entries ?? const <CandidateRankingEntry>[];
    final scores = applicants
        .map((app) =>
            ranked
                .where((entry) => entry.applicationId == app.id)
                .firstOrNull
                ?.score ??
            app.aiScore)
        .whereType<int>()
        .toList();
    final average =
        scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
    final rationale = ranked
        .map((entry) => entry.insight.trim())
        .where((insight) => insight.isNotEmpty)
        .take(2)
        .toList();
    final summary = average == null
        ? 'Applicant profiles and application stages are available below. AI comparison insights will appear after scoring completes.'
        : rationale.isEmpty
            ? 'The current average AI match score is ${average.toStringAsFixed(1)}% across ${scores.length} scored candidates.'
            : rationale.join('\n\n');
    final insights = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: const Color(0xFF080D33),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.psychology_alt_outlined,
              color: Color(0xFFFFB08A), size: 21),
          SizedBox(width: 9),
          Text('AI Comparison Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        Text(summary,
            style: const TextStyle(
                color: Color(0xFFD9DCEE), height: 1.7, fontSize: 12)),
        const SizedBox(height: 18),
        Row(children: [
          _SummaryMetric(
              label: 'AVG. RANKING',
              value: average == null ? '—' : average.toStringAsFixed(1)),
          const SizedBox(width: 22),
          _SummaryMetric(
              label: 'SCORED', value: '${scores.length}/${applicants.length}'),
        ]),
      ]),
    );
    final skills = _SkillCoverageCard(
        applicants: applicants, requiredSkills: requiredSkills);
    if (!wide) {
      return Column(children: [insights, const SizedBox(height: 14), skills]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 2, child: insights),
      const SizedBox(width: 16),
      Expanded(child: skills),
    ]);
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9BA4C2),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFFFD5C2),
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ],
      );
}

class _SkillCoverageCard extends StatelessWidget {
  const _SkillCoverageCard(
      {required this.applicants, required this.requiredSkills});
  final List<JobApplicantSummary> applicants;
  final List<String> requiredSkills;

  @override
  Widget build(BuildContext context) {
    final matches = applicants.map((applicant) {
      final skills =
          applicant.candidate.skills.map((e) => e.toLowerCase()).toSet();
      final matched = requiredSkills
          .where((skill) => skills.contains(skill.toLowerCase()))
          .length;
      final ratio =
          requiredSkills.isEmpty ? 0.0 : matched / requiredSkills.length;
      return (applicant: applicant, matched: matched, ratio: ratio);
    }).toList();
    final hasProfileSkills = matches
        .any((candidate) => candidate.applicant.candidate.skills.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE7C9B9)),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('REQUIRED SKILL COVERAGE',
            style: TextStyle(
                color: BrandColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .5)),
        const SizedBox(height: 12),
        if (!hasProfileSkills || requiredSkills.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Skill coverage will appear when candidate profiles and job requirements include skills.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: BrandColors.muted, fontSize: 11, height: 1.4),
              ),
            ),
          )
        else
          for (final candidate in matches)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(candidate.applicant.candidate.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: BrandColors.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      Text(
                          '${candidate.matched}/${requiredSkills.length} skills',
                          style: const TextStyle(
                              color: BrandColors.muted, fontSize: 10)),
                    ]),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: candidate.ratio,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      backgroundColor: const Color(0xFFE8EEF8),
                      color: BrandColors.orange,
                    ),
                  ]),
            ),
      ]),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.applicants, required this.ranking});
  final List<JobApplicantSummary> applicants;
  final CandidateRankingResult? ranking;

  @override
  Widget build(BuildContext context) {
    final entries = {
      for (final entry in ranking?.entries ?? const <CandidateRankingEntry>[])
        entry.applicationId: entry,
    };
    final rows = <(String, String Function(JobApplicantSummary))>[
      (
        'AI Match Score',
        (app) => entries[app.id]?.score == null && app.aiScore == null
            ? 'Pending'
            : '${entries[app.id]?.score ?? app.aiScore}%'
      ),
      (
        'Years of Experience',
        (app) => app.candidate.yearsOfExperience == null
            ? 'Not provided'
            : '${app.candidate.yearsOfExperience} years'
      ),
      (
        'Core Skills',
        (app) => app.candidate.skills.isEmpty
            ? 'Not provided'
            : app.candidate.skills.take(5).join(', ')
      ),
      (
        'Education / Field of Study',
        (app) => app.candidate.education.isEmpty
            ? 'Not provided'
            : app.candidate.education.take(2).join('\n')
      ),
      ('Application Stage', (app) => app.status.label),
      ('Location', (app) => app.candidate.location ?? 'Not provided'),
      (
        'AI Strengths',
        (app) => entries[app.id]?.strengths.isEmpty ?? true
            ? 'Available after ranking'
            : entries[app.id]!.strengths.join(', ')
      ),
    ];
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (240 + applicants.length * 230).clamp(700, 1440).toDouble(),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFD),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14))),
              child: Row(children: [
                const SizedBox(
                    width: 220,
                    child: Text('COMPARISON METRIC', style: _tableHeader)),
                for (final applicant in applicants)
                  Expanded(
                    child: Text(applicant.candidate.fullName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: BrandColors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
            for (final (label, value) in rows)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: BrandColors.border))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 220,
                          child: Text(label,
                              style: const TextStyle(
                                  color: BrandColors.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))),
                      for (final applicant in applicants)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(value(applicant),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: BrandColors.navy,
                                    fontSize: 11,
                                    height: 1.35)),
                          ),
                        ),
                    ]),
              ),
          ]),
        ),
      ),
    );
  }

  static const _tableHeader = TextStyle(
      color: BrandColors.muted,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: .4);
}

class _CandidateFact extends StatelessWidget {
  const _CandidateFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: BrandColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: BrandColors.muted, fontSize: 10, height: 1.2)),
          ),
        ]),
      );
}

class _StrengthChips extends StatelessWidget {
  const _StrengthChips({required this.strengths});
  final List<String> strengths;

  @override
  Widget build(BuildContext context) {
    if (strengths.isEmpty) {
      return const Text('Skills not provided',
          style: TextStyle(fontSize: 10, color: BrandColors.muted));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: strengths
          .take(4)
          .map((skill) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFE6EDFF),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(skill,
                    style:
                        const TextStyle(fontSize: 9, color: Color(0xFF50528A))),
              ))
          .toList(),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.applicant});
  final JobApplicantSummary applicant;

  @override
  Widget build(BuildContext context) {
    final url = applicant.candidate.profileImageUrl;
    return CircleAvatar(
      radius: 27,
      backgroundColor: BrandColors.navy.withValues(alpha: .1),
      backgroundImage: url == null ? null : NetworkImage(url),
      child: url == null
          ? Text(applicant.candidate.initials,
              style: const TextStyle(
                  color: BrandColors.navy, fontWeight: FontWeight.w800))
          : null,
    );
  }
}

class _ApplicationStatusBadge extends StatelessWidget {
  const _ApplicationStatusBadge({required this.status});
  final ApplicationBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ApplicationBackendStatus.shortlisted
        ? const Color(0xFF087A51)
        : status == ApplicationBackendStatus.rejected
            ? const Color(0xFF9B4040)
            : BrandColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.label.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}

class _RankingNotice extends StatelessWidget {
  const _RankingNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF7EC),
            border: Border.all(color: const Color(0xFFF2D8AF)),
            borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 17, color: BrandColors.orange),
          const SizedBox(width: 9),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 11, height: 1.45, color: BrandColors.navy))),
        ]),
      );
}

class _NoApplicants extends StatelessWidget {
  const _NoApplicants({required this.onViewApplicants});
  final VoidCallback onViewApplicants;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BrandColors.border),
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          const Icon(Icons.people_outline, size: 34, color: BrandColors.muted),
          const SizedBox(height: 10),
          const Text('No applicants to compare yet',
              style: TextStyle(
                  color: BrandColors.navy, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Applicants will appear here as soon as they apply.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onViewApplicants,
              child: const Text('Open applicant list')),
        ]),
      );
}

class _ComparisonError extends StatelessWidget {
  const _ComparisonError({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onBack, child: const Text('Back to jobs')),
        ]),
      );
}
