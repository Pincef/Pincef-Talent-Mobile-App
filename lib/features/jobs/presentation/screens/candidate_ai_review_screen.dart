import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/brand_color.dart';
import '../../application/candidate_profile_provider.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/candidate_analysis_model.dart';
import '../../data/models/candidate_profile_model.dart';
import '../../data/models/candidate_ranking_model.dart';

enum CandidateAiReviewView { match, parsing, summary }

class CandidateAiReviewScreen extends ConsumerWidget {
  const CandidateAiReviewScreen({
    super.key,
    required this.jobId,
    required this.candidateId,
    required this.view,
    this.rankingEntry,
  });

  final String jobId;
  final String candidateId;
  final CandidateAiReviewView view;
  final CandidateRankingEntry? rankingEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view == CandidateAiReviewView.summary) {
      return _SummaryView(
        entry: rankingEntry,
        candidateId: candidateId,
        jobId: jobId,
      );
    }

    final args = (candidateId: candidateId, jobId: jobId);
    final asyncData = ref.watch(candidateProfileViewProvider(args));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _LoadError(
        message: error.toString(),
        onRetry: () => ref.invalidate(candidateProfileViewProvider(args)),
      ),
      data: (data) => view == CandidateAiReviewView.match
          ? _MatchView(
              data: data,
              jobId: jobId,
              candidateId: candidateId,
              rankingEntry: rankingEntry,
            )
          : _ParsingView(data: data, jobId: jobId, candidateId: candidateId),
    );
  }
}

class _MatchView extends StatelessWidget {
  const _MatchView({
    required this.data,
    required this.jobId,
    required this.candidateId,
    this.rankingEntry,
  });
  final CandidateProfileViewData data;
  final String jobId;
  final String candidateId;
  final CandidateRankingEntry? rankingEntry;

  @override
  Widget build(BuildContext context) {
    final analysis = data.analysis;
    final profile = data.profile;
    final score = rankingEntry?.score ?? analysis?.score;
    final status = analysis?.status;
    final skills = profile.skills.take(12).toList();
    return _PageFrame(
      jobId: jobId,
      candidateId: candidateId,
      currentLabel: 'AI CV-to-Job Matching',
      eyebrow: 'CANDIDATE MATCH',
      title: 'AI CV-to-Job Matching',
      subtitle: 'How ${data.user.fullName} aligns with this role',
      candidateName: data.user.fullName,
      candidateImageUrl: data.user.profileImage?.url,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.push('/jobs/$jobId/candidates/$candidateId'),
          icon: const Icon(Icons.person_outline),
          label: const Text('View Candidate Profile'),
        ),
      ],
      children: [
        if (status == CandidateJobAnalysisStatus.failed && rankingEntry == null)
          _NoticeCard(
            icon: Icons.error_outline,
            message: analysis?.error ?? 'We could not calculate this match.',
          )
        else if (rankingEntry == null &&
            (status != CandidateJobAnalysisStatus.completed || score == null))
          const _NoticeCard(
            icon: Icons.hourglass_top,
            message:
                'The match analysis is not ready yet. Refresh the ranking and try again shortly.',
          )
        else ...[
          _Panel(
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final scoreRing = Container(
                width: 194,
                height: 194,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: BrandColors.orange, width: 12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$score%',
                        style: const TextStyle(
                            color: BrandColors.orange,
                            fontSize: 44,
                            fontWeight: FontWeight.w800)),
                    const Text('MATCH SCORE',
                        style: TextStyle(
                            color: BrandColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5)),
                  ],
                ),
              );
              final insightPanel = Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 194),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: BrandColors.navy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.auto_awesome,
                          color: BrandColors.orange, size: 20),
                      SizedBox(width: 9),
                      Text('AI Talent Insight',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),
                    Text(
                      rankingEntry?.insight.trim().isNotEmpty == true
                          ? rankingEntry!.insight
                          : analysis?.summary?.trim().isNotEmpty == true
                              ? analysis!.summary!
                              : 'The AI match score is available, but a written explanation has not been generated.',
                      style:
                          const TextStyle(color: Colors.white70, height: 1.6),
                    ),
                  ],
                ),
              );
              if (compact) {
                return Column(children: [
                  scoreRing,
                  const SizedBox(height: 20),
                  insightPanel,
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  scoreRing,
                  const SizedBox(width: 24),
                  Expanded(child: insightPanel),
                ],
              );
            }),
          ),
          if (skills.isNotEmpty)
            _Panel(
              title: 'Candidate skills from CV',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map((skill) => Chip(
                          label: Text(skill),
                          backgroundColor: const Color(0xFFF0F4FF),
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            ),
          if (rankingEntry?.strengths.isNotEmpty == true)
            _Panel(
              title: 'Match highlights',
              child: Column(
                children: rankingEntry!.strengths
                    .map((highlight) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Color(0xFF16A34A), size: 18),
                                const SizedBox(width: 9),
                                Expanded(
                                    child: Text(highlight,
                                        style: const TextStyle(height: 1.45))),
                              ]),
                        ))
                    .toList(),
              ),
            ),
          _Panel(
            title: 'Profile context',
            child: Text(
              '${profile.experience.length} work history item(s) · ${profile.education.length} education item(s) · ${profile.skills.length} listed skills',
              style: const TextStyle(color: BrandColors.muted, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _ParsingView extends ConsumerWidget {
  const _ParsingView({
    required this.data,
    required this.jobId,
    required this.candidateId,
  });

  final CandidateProfileViewData data;
  final String jobId;
  final String candidateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = data.profile;
    final args = (candidateId: candidateId, jobId: jobId);
    return _PageFrame(
      jobId: jobId,
      candidateId: candidateId,
      currentLabel: 'AI CV Parsing',
      eyebrow: 'CV EXTRACTION',
      title: 'AI CV Parsing Results',
      subtitle: 'Extracted candidate information from the profile CV',
      candidateName: data.user.fullName,
      candidateImageUrl: data.user.profileImage?.url,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.push('/jobs/$jobId/candidates/$candidateId'),
          icon: const Icon(Icons.person_outline),
          label: const Text('View Candidate Profile'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await ref
                  .read(candidateProfileViewRepositoryProvider)
                  .requestCvParsing(candidateId, jobId);
              ref.invalidate(candidateProfileViewProvider(args));
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not parse CV: $error')));
              }
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Re-run parsing'),
        ),
      ],
      children: [
        if (profile.cvFiles.isNotEmpty)
          _Panel(
            title: 'Original CV document',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: profile.cvFiles
                    .map((cv) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.picture_as_pdf_outlined,
                              color: BrandColors.orange),
                          title: Text(cv.originalName),
                          subtitle: Text(
                              '${cv.sizeLabel} · Uploaded ${cv.uploadedAt.toLocal().toString().split(' ').first}'),
                          trailing: IconButton(
                              tooltip: 'Open CV',
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () async {
                                final uri = Uri.tryParse(cv.url);
                                if (uri != null) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }),
                        ))
                    .toList()),
          ),
        _Panel(
          title: 'Contact information',
          child: Wrap(spacing: 32, runSpacing: 16, children: [
            _ValueBlock(label: 'FULL NAME', value: data.user.fullName),
            _ValueBlock(label: 'EMAIL', value: data.user.email),
            _ValueBlock(
                label: 'PHONE', value: data.user.phone ?? 'Not provided'),
            _ValueBlock(
                label: 'LOCATION',
                value: profile.location?.displayString.isNotEmpty == true
                    ? profile.location!.displayString
                    : 'Not provided'),
          ]),
        ),
        _Panel(
          title: 'Work history',
          child: profile.experience.isEmpty
              ? const Text('No work history has been extracted.')
              : Column(
                  children: profile.experience
                      .map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.work_outline,
                                color: BrandColors.orange),
                            title: Text(item.title),
                            subtitle: Text([
                              if (item.company?.isNotEmpty == true)
                                item.company!,
                              if (item.description?.isNotEmpty == true)
                                item.description!,
                            ].join(' · ')),
                          ))
                      .toList(),
                ),
        ),
        _Panel(
          title: 'Skills and expertise',
          child: profile.skills.isEmpty
              ? const Text('No skills have been extracted.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.skills
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
        ),
        _Panel(
          title: 'Education',
          child: profile.education.isEmpty
              ? const Text('No education has been extracted.')
              : Column(
                  children: profile.education
                      .map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.school_outlined,
                                color: BrandColors.orange),
                            title: Text(item.institution),
                            subtitle: Text([
                              if (item.degree?.isNotEmpty == true) item.degree!,
                              if (item.fieldOfStudy?.isNotEmpty == true)
                                item.fieldOfStudy!,
                            ].join(' · ')),
                          ))
                      .toList(),
                ),
        ),
        if (profile.certifications.isNotEmpty)
          _Panel(
            title: 'Certifications',
            child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.certifications
                    .map((item) => Chip(
                          avatar: Icon(
                              item.status == ProfileCertificationStatus.verified
                                  ? Icons.verified
                                  : Icons.hourglass_top,
                              size: 16),
                          label: Text(item.name),
                        ))
                    .toList()),
          ),
      ],
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({
    required this.entry,
    required this.candidateId,
    required this.jobId,
  });

  final CandidateRankingEntry? entry;
  final String candidateId;
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (candidateId: candidateId, jobId: jobId);
    final profileAsync = ref.watch(candidateProfileViewProvider(args));
    final data = profileAsync.valueOrNull;
    final summary = entry?.resumeSummary ??
        data?.analysis?.resumeSummary ??
        const <String, dynamic>{};
    final executive = summary['executiveSummary']?.toString().trim() ?? '';
    final achievements = (summary['topAchievements'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final skills = (summary['skills'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final competencies = (summary['competencies'] as List? ?? const [])
        .whereType<String>()
        .toList();
    return _PageFrame(
      jobId: jobId,
      candidateId: candidateId,
      currentLabel: 'Summary',
      eyebrow: 'AI GENERATED',
      title: 'AI Resume Summary',
      subtitle: data == null
          ? (entry?.name ?? 'Candidate summary')
          : '${data.profile.professionalTitle ?? 'Candidate'} · ${entry?.fitLabel ?? 'AI summary'}',
      candidateName: data?.user.fullName ?? entry?.name,
      candidateImageUrl: data?.user.profileImage?.url ?? entry?.avatarUrl,
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.push('/jobs/$jobId/candidates/$candidateId'),
          icon: const Icon(Icons.person_outline),
          label: const Text('View Candidate Profile'),
        ),
      ],
      children: [
        if (profileAsync.isLoading && entry == null)
          const _NoticeCard(
              icon: Icons.hourglass_top,
              message: 'Loading the candidate summary…')
        else if (entry == null && data == null)
          const _NoticeCard(
              icon: Icons.info_outline,
              message: 'Candidate summary is unavailable right now.')
        else if (summary.isEmpty)
          const _NoticeCard(
              icon: Icons.hourglass_empty,
              message:
                  'An AI resume summary has not been generated for this candidate yet.')
        else ...[
          if (entry != null)
            _Panel(
                child: Row(children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text('${entry!.score}% match · ${entry!.fitLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          _Panel(
            title: 'Executive summary',
            child: Text(
                executive.isEmpty
                    ? (data?.profile.displaySummary ??
                        'No executive summary is available.')
                    : executive,
                style: const TextStyle(height: 1.6)),
          ),
          if (achievements.isNotEmpty)
            _Panel(
              title: 'Top achievements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: achievements
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item)),
                              ]),
                        ))
                    .toList(),
              ),
            ),
          if (skills.isNotEmpty)
            _Panel(
              title: 'Relevant skills',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map((skill) => Chip(
                          label: Text([
                            skill['name']?.toString() ?? '',
                            if (skill['level'] != null)
                              skill['level'].toString(),
                          ].where((value) => value.isNotEmpty).join(' · ')),
                        ))
                    .toList(),
              ),
            ),
          if (competencies.isNotEmpty)
            _Panel(
                title: 'Core competencies',
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: competencies
                        .map((value) => Chip(label: Text(value)))
                        .toList())),
          if (data?.profile.education.isNotEmpty == true)
            _Panel(
                title: 'Education',
                child: Column(
                    children: data!.profile.education
                        .map((item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.school_outlined,
                                color: BrandColors.orange),
                            title: Text(item.degree ??
                                item.fieldOfStudy ??
                                item.institution),
                            subtitle: Text([
                              if (item.fieldOfStudy != null) item.fieldOfStudy!,
                              item.institution
                            ].join(' · '))))
                        .toList())),
          if (data?.profile.certifications.isNotEmpty == true)
            _Panel(
                title: 'Certifications',
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data!.profile.certifications
                        .map((item) => Chip(label: Text(item.name)))
                        .toList())),
        ],
      ],
    );
  }
}

class _PageFrame extends ConsumerWidget {
  const _PageFrame({
    required this.jobId,
    required this.candidateId,
    required this.currentLabel,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
    this.candidateName,
    this.candidateImageUrl,
    this.actions = const [],
  });

  final String jobId;
  final String candidateId;
  final String currentLabel;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? candidateName;
  final String? candidateImageUrl;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final jobTitle = jobAsync.valueOrNull?.title ?? 'Job';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewBreadcrumb(
                    jobId: jobId,
                    jobTitle: jobTitle,
                    candidateId: candidateId,
                    candidateName: candidateName ?? 'Candidate',
                    currentLabel: currentLabel,
                  ),
                  const SizedBox(height: 18),
                  Text(eyebrow,
                      style: const TextStyle(
                          color: BrandColors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8)),
                  const SizedBox(height: 7),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 12,
                    spacing: 20,
                    children: [
                      SizedBox(
                        width: compact ? constraints.maxWidth - 32 : 640,
                        child: Row(children: [
                          if (candidateName != null) ...[
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: candidateImageUrl == null
                                  ? null
                                  : NetworkImage(candidateImageUrl!),
                              child: candidateImageUrl == null
                                  ? const Icon(Icons.person_outline)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        color: BrandColors.navy,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800)),
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: BrandColors.muted,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ),
                  const SizedBox(height: 22),
                  ...children.map((child) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: child,
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReviewBreadcrumb extends StatelessWidget {
  const _ReviewBreadcrumb({
    required this.jobId,
    required this.jobTitle,
    required this.candidateId,
    required this.candidateName,
    required this.currentLabel,
  });

  final String jobId;
  final String jobTitle;
  final String candidateId;
  final String candidateName;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String?, bool)>[
      ('Jobs', '/jobs', false),
      (jobTitle, '/jobs/$jobId', false),
      ('AI Candidate Ranking', '/jobs/$jobId/candidate-ranking', false),
      (candidateName, '/jobs/$jobId/candidates/$candidateId', false),
      (currentLabel, null, true),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right,
                    size: 15, color: BrandColors.muted),
              ),
            if (items[i].$2 == null)
              Text(items[i].$1,
                  style: TextStyle(
                    fontSize: 12,
                    color: items[i].$3 ? BrandColors.orange : BrandColors.muted,
                    fontWeight: items[i].$3 ? FontWeight.w700 : FontWeight.w500,
                  ))
            else
              InkWell(
                onTap: () => context.go(items[i].$2!),
                child: Text(items[i].$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BrandColors.muted,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080D1935), blurRadius: 14, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!,
                  style: const TextStyle(
                      color: BrandColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      );
}

class _ValueBlock extends StatelessWidget {
  const _ValueBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: BrandColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: BrandColors.navy, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: BrandColors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(height: 1.5))),
        ]),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load candidate AI details.'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
      );
}
