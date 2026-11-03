import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/brand_color.dart';
import '../../application/candidate_profile_provider.dart';
import '../../application/candidate_ranking_provider.dart';
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
          : _ParsingView(
              data: data,
              jobId: jobId,
              candidateId: candidateId,
              rankingEntry: rankingEntry,
            ),
    );
  }
}

class _MatchView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = data.analysis;
    final profile = data.profile;
    final score = rankingEntry?.score ?? analysis?.score;
    final status = analysis?.status;
    final job = ref.watch(jobDetailProvider(jobId)).valueOrNull;
    final ranking = ref.watch(candidateRankingProvider(jobId)).valueOrNull;
    final applicationSkills =
        (rankingEntry?.parsedResume?['skills'] as List? ?? const [])
            .whereType<String>()
            .toList();
    final skills =
        (applicationSkills.isNotEmpty ? applicationSkills : profile.skills)
            .take(12)
            .toList();
    final applicationExperience =
        rankingEntry?.parsedResume?['experience'] as List?;
    final experienceCount =
        applicationExperience?.length ?? profile.experience.length;
    final requiredSkills = job?.requiredSkills ?? const <String>[];
    final matchedSkills = requiredSkills
        .where((required) => _containsSkill(skills, required))
        .toList();
    final missingSkills = requiredSkills
        .where((required) => !_containsSkill(skills, required))
        .toList();
    final candidateYears =
        (rankingEntry?.parsedResume?['yearsOfExperience'] as num?)
                ?.toDouble() ??
            rankingEntry?.experienceYears?.toDouble();
    final minimumYears = _firstNumber(job?.minYearsOfExperience);
    final experienceMeetsRequirement = candidateYears != null &&
        minimumYears != null &&
        candidateYears >= minimumYears;
    final requirements = <(String, String)>[
      for (final skill in matchedSkills)
        (skill, 'Evidence found in the CV attached to this application.'),
      if (minimumYears != null && experienceMeetsRequirement)
        (
          '${minimumYears.round()}+ years relevant experience',
          'The application CV indicates about ${candidateYears.round()} years of experience.'
        ),
      if (job?.educationLevelLabel != null &&
          _educationMatches(
            rankingEntry?.parsedResume?['education'],
            job!.educationLevelLabel!,
            job.fieldOfStudy,
          ))
        (
          job.educationLevelLabel!,
          'A matching qualification or field of study appears in the application CV.'
        ),
    ];
    final gaps = <String>[
      for (final skill in missingSkills)
        'No evidence for $skill was found in the application CV.',
      if (minimumYears != null &&
          candidateYears != null &&
          !experienceMeetsRequirement)
        'The CV indicates about ${candidateYears.round()} years of experience; this role asks for ${minimumYears.round()}+.',
      if (minimumYears != null && candidateYears == null)
        'Experience duration could not be confirmed from this CV.',
      if (job?.educationLevelLabel != null &&
          !_educationMatches(
            rankingEntry?.parsedResume?['education'],
            job!.educationLevelLabel!,
            job.fieldOfStudy,
          ))
        'The requested ${job.educationLevelLabel}${job.fieldOfStudy?.isNotEmpty == true ? ' in ${job.fieldOfStudy}' : ''} was not clearly found in the application CV.',
    ];
    final comparisonEntries =
        ranking?.entries ?? const <CandidateRankingEntry>[];
    final comparisonCandidate = _findComparisonCandidate(
      comparisonEntries,
      rankingEntry,
      candidateId,
    );
    final comparisonScore = comparisonCandidate?.score ?? score;
    final averageScore = ranking?.avgMatchScore;
    final scoreDifference = comparisonScore != null && averageScore != null
        ? (comparisonScore - averageScore).round()
        : null;
    final currentSkillOverlap = _skillOverlap(requiredSkills, skills);
    final averageSkillOverlap = _averageSkillOverlap(
      requiredSkills,
      comparisonEntries,
    );
    final averageExperience = _averageExperience(comparisonEntries);
    final candidateRank = comparisonCandidate?.rank;
    final comparisonTotal = ranking?.totalRanked ?? comparisonEntries.length;
    return _PageFrame(
      jobId: jobId,
      candidateId: candidateId,
      currentLabel: 'Job Match Results',
      eyebrow: 'AI TO CV JOB MATCH',
      title: 'Job Match Results',
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
          _MatchEvidenceGrid(
            requirements: requirements,
            gaps: gaps,
            requiredSkillsAvailable: requiredSkills.isNotEmpty,
            comparisonName: data.user.fullName,
            scoreDifference: scoreDifference,
            candidateRank: candidateRank,
            totalCandidates: comparisonTotal,
            candidateYears: candidateYears,
            averageExperience: averageExperience,
            skillOverlap: currentSkillOverlap,
            averageSkillOverlap: averageSkillOverlap,
          ),
          if (skills.isNotEmpty)
            _Panel(
              title: 'Skills found in application CV',
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
              title: 'AI match highlights',
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
            title: 'Application CV context',
            child: Text(
              '$experienceCount work history item(s) · ${rankingEntry?.parsedResume?['education'] is List ? (rankingEntry!.parsedResume!['education'] as List).length : profile.education.length} education item(s) · ${skills.length} listed skills',
              style: const TextStyle(color: BrandColors.muted, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

bool _containsSkill(List<String> skills, String requiredSkill) {
  String normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final required = normalize(requiredSkill);
  if (required.isEmpty) return false;
  return skills.any((skill) {
    final candidate = normalize(skill);
    return candidate == required ||
        (candidate.length >= 5 && required.contains(candidate)) ||
        (required.length >= 5 && candidate.contains(required));
  });
}

int? _firstNumber(String? value) {
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(value ?? '');
  return match == null ? null : double.tryParse(match.group(0)!)?.round();
}

bool _educationMatches(dynamic rawEducation, String level, String? field) {
  final education = (rawEducation as List? ?? const []).whereType<Map>();
  final levelTerms = switch (level.toLowerCase()) {
    'high school' => ['high school', 'secondary school', 'ged'],
    'associate degree' => ['associate', 'a.a.', 'a.s.', 'a.a.s.'],
    "bachelor's degree" => ['bachelor', 'b.a.', 'b.s.', 'b.sc', 'b.eng'],
    "master's degree" => ['master', 'm.a.', 'm.s.', 'm.sc', 'mba', 'm.eng'],
    'doctorate' => ['doctor', 'ph.d', 'phd', 'd.phil'],
    _ => [level.toLowerCase()],
  };
  final normalizedField = field?.trim().toLowerCase();
  return education.any((item) {
    final text = [item['degree'], item['fieldOfStudy']]
        .whereType<String>()
        .join(' ')
        .toLowerCase();
    final levelFound = levelTerms.any(text.contains);
    final fieldFound = normalizedField == null ||
        normalizedField.isEmpty ||
        text.contains(normalizedField);
    return levelFound && fieldFound;
  });
}

CandidateRankingEntry? _findComparisonCandidate(
  List<CandidateRankingEntry> entries,
  CandidateRankingEntry? source,
  String candidateId,
) {
  for (final entry in entries) {
    if (source != null && entry.applicationId == source.applicationId) {
      return entry;
    }
  }
  for (final entry in entries) {
    if (entry.candidateId == candidateId) return entry;
  }
  return source;
}

int? _skillOverlap(List<String> requirements, List<String> skills) {
  if (requirements.isEmpty || skills.isEmpty) return null;
  final matched =
      requirements.where((item) => _containsSkill(skills, item)).length;
  return (matched / requirements.length * 100).round();
}

int? _averageSkillOverlap(
  List<String> requirements,
  List<CandidateRankingEntry> entries,
) {
  final values = entries
      .map((entry) => (entry.parsedResume?['skills'] as List? ?? const [])
          .whereType<String>()
          .toList())
      .map((skills) => _skillOverlap(requirements, skills))
      .whereType<int>()
      .toList();
  if (values.isEmpty) return null;
  return (values.reduce((a, b) => a + b) / values.length).round();
}

double? _experienceYears(CandidateRankingEntry entry) =>
    (entry.parsedResume?['yearsOfExperience'] as num?)?.toDouble() ??
    entry.experienceYears?.toDouble();

double? _averageExperience(List<CandidateRankingEntry> entries) {
  final values = entries.map(_experienceYears).whereType<double>().toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

class _MatchEvidenceGrid extends StatelessWidget {
  const _MatchEvidenceGrid({
    required this.requirements,
    required this.gaps,
    required this.requiredSkillsAvailable,
    required this.comparisonName,
    required this.scoreDifference,
    required this.candidateRank,
    required this.totalCandidates,
    required this.candidateYears,
    required this.averageExperience,
    required this.skillOverlap,
    required this.averageSkillOverlap,
  });

  final List<(String, String)> requirements;
  final List<String> gaps;
  final bool requiredSkillsAvailable;
  final String comparisonName;
  final int? scoreDifference;
  final int? candidateRank;
  final int totalCandidates;
  final double? candidateYears;
  final double? averageExperience;
  final int? skillOverlap;
  final int? averageSkillOverlap;

  @override
  Widget build(BuildContext context) {
    final matchedCard = _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 9),
          const Expanded(
              child: Text('Matched Requirements',
                  style: TextStyle(
                      color: BrandColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800))),
          _CountPill(
              label: '${requirements.length} criteria met', positive: true),
        ]),
        const SizedBox(height: 14),
        if (requirements.isEmpty)
          Text(
            requiredSkillsAvailable
                ? 'No matching requirements could be confirmed from the application CV.'
                : 'This job has no structured requirements available for comparison.',
            style: const TextStyle(color: BrandColors.muted, height: 1.5),
          )
        else
          for (final item in requirements)
            _CriterionTile(label: item.$1, evidence: item.$2, positive: true),
      ]),
    );

    final considerationCard = _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: BrandColors.orange, size: 21),
          const SizedBox(width: 9),
          const Expanded(
              child: Text('Gaps & Considerations',
                  style: TextStyle(
                      color: BrandColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800))),
          _CountPill(label: '${gaps.length} to review', positive: false),
        ]),
        const SizedBox(height: 14),
        if (gaps.isEmpty)
          const Text('No gaps were identified from the available CV evidence.',
              style: TextStyle(color: BrandColors.muted, height: 1.5))
        else
          for (final gap in gaps) _CriterionTile(label: gap, positive: false),
        const SizedBox(height: 14),
        _CandidateComparisonCard(
          name: comparisonName,
          scoreDifference: scoreDifference,
          rank: candidateRank,
          total: totalCandidates,
          years: candidateYears,
          averageYears: averageExperience,
          skillOverlap: skillOverlap,
          averageSkillOverlap: averageSkillOverlap,
        ),
      ]),
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 650) {
        return Column(children: [
          matchedCard,
          const SizedBox(height: 16),
          considerationCard
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 11, child: matchedCard),
        const SizedBox(width: 16),
        Expanded(flex: 10, child: considerationCard),
      ]);
    });
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.positive});
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF079669) : const Color(0xFFB66A00);
    final background =
        positive ? const Color(0xFFE7FBF3) : const Color(0xFFFFF5DB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _CriterionTile extends StatelessWidget {
  const _CriterionTile({
    required this.label,
    this.evidence,
    required this.positive,
  });
  final String label;
  final String? evidence;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF0B9C6B) : BrandColors.orange;
    final background =
        positive ? const Color(0xFFF7FAFC) : const Color(0xFFFFFAF5);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE8EEF4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(positive ? Icons.check_circle_outline : Icons.error_outline,
            color: color, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: BrandColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35)),
            if (evidence?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(evidence!,
                  style: const TextStyle(
                      color: BrandColors.muted, fontSize: 12, height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _CandidateComparisonCard extends StatelessWidget {
  const _CandidateComparisonCard({
    required this.name,
    required this.scoreDifference,
    required this.rank,
    required this.total,
    required this.years,
    required this.averageYears,
    required this.skillOverlap,
    required this.averageSkillOverlap,
  });

  final String name;
  final int? scoreDifference;
  final int? rank;
  final int total;
  final double? years;
  final double? averageYears;
  final int? skillOverlap;
  final int? averageSkillOverlap;

  @override
  Widget build(BuildContext context) {
    final topPercent = rank != null && total > 0
        ? ((rank! / total) * 100).ceil().clamp(1, 100)
        : null;
    final scoreText = scoreDifference == null
        ? 'Comparison score is not available yet.'
        : scoreDifference! > 0
            ? '$name scores ${scoreDifference!.abs()} percentage points above the applicant average.'
            : scoreDifference! < 0
                ? '$name scores ${scoreDifference!.abs()} percentage points below the applicant average.'
                : '$name is currently at the applicant average.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD7E8FF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.groups_outlined, color: Color(0xFF3978FF), size: 17),
          const SizedBox(width: 7),
          const Expanded(
              child: Text('CANDIDATE COMPARISON',
                  style: TextStyle(
                      color: Color(0xFF3978FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5))),
          if (topPercent != null)
            Text('TOP $topPercent%',
                style: const TextStyle(
                    color: Color(0xFF3978FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 9),
        Text(scoreText,
            style: const TextStyle(
                color: BrandColors.navy, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          if (years != null)
            _ComparisonMetric(
                label: 'Experience',
                value: '${years!.toStringAsFixed(years! % 1 == 0 ? 0 : 1)} yrs',
                average: averageYears == null
                    ? null
                    : '${averageYears!.toStringAsFixed(averageYears! % 1 == 0 ? 0 : 1)} yr avg'),
          if (skillOverlap != null)
            _ComparisonMetric(
                label: 'Skills overlap',
                value: '$skillOverlap%',
                average: averageSkillOverlap == null
                    ? null
                    : '$averageSkillOverlap% avg'),
        ]),
      ]),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    this.average,
  });
  final String label;
  final String value;
  final String? average;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD7E8FF)),
        ),
        child: Text('$label: $value${average == null ? '' : ' (vs $average)'}',
            style: const TextStyle(color: BrandColors.muted, fontSize: 10)),
      );
}

class _ParsingView extends StatelessWidget {
  const _ParsingView({
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
    final profile = data.profile;
    final parsed = rankingEntry?.parsedResume;
    final extractedSkills =
        (parsed?['skills'] as List? ?? const []).whereType<String>().toList();
    final extractedExperience = (parsed?['experience'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final extractedEducation = (parsed?['education'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    String extractedContact(String key) {
      final value = parsed?[key];
      if (value is! String || value.trim().isEmpty) return 'Not provided';
      return value.trim();
    }

    String manualContact(String? value) =>
        value == null || value.trim().isEmpty ? 'Not provided' : value.trim();
    final email = rankingEntry == null
        ? manualContact(data.user.email)
        : extractedContact('email');
    final phone = rankingEntry == null
        ? manualContact(data.user.phone)
        : extractedContact('phone');
    return _PageFrame(
      jobId: jobId,
      candidateId: candidateId,
      currentLabel:
          rankingEntry == null ? 'Candidate Profile' : 'AI CV Parsing',
      eyebrow: rankingEntry == null ? 'CANDIDATE PROFILE' : 'CV EXTRACTION',
      title: rankingEntry == null
          ? 'Candidate Profile Details'
          : 'AI CV Parsing Results',
      subtitle: rankingEntry == null
          ? 'Details entered manually by the candidate.'
          : 'Extracted from the exact CV used for this application’s AI review',
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
        if (rankingEntry?.sourceCvUrl?.isNotEmpty == true)
          _Panel(
            title: 'Original application CV',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: BrandColors.orange),
              title: Text(
                  rankingEntry?.parsedResume?['originalName']?.toString() ??
                      'CV used for this application'),
              subtitle:
                  const Text('The exact CV used for this job’s AI review'),
              trailing: IconButton(
                tooltip: 'Open application CV',
                icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                  final uri = Uri.tryParse(rankingEntry!.sourceCvUrl!);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          )
        else if (profile.cvFiles.isNotEmpty)
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
            _ValueBlock(label: 'EMAIL', value: email),
            _ValueBlock(label: 'PHONE', value: phone),
            _ValueBlock(
                label: 'LOCATION',
                value: profile.location?.displayString.isNotEmpty == true
                    ? profile.location!.displayString
                    : 'Not provided'),
          ]),
        ),
        _Panel(
          title: 'Work history',
          child: (extractedExperience.isEmpty && profile.experience.isEmpty)
              ? const Text('No work history has been extracted.')
              : Column(
                  children: extractedExperience.isNotEmpty
                      ? extractedExperience
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.work_outline,
                                    color: BrandColors.orange),
                                title:
                                    Text(item['title']?.toString() ?? 'Role'),
                                subtitle: Text([
                                  item['company']?.toString(),
                                  item['description']?.toString(),
                                ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · ')),
                              ))
                          .toList()
                      : profile.experience
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
          child: extractedSkills.isEmpty && profile.skills.isEmpty
              ? const Text('No skills have been extracted.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (extractedSkills.isNotEmpty
                          ? extractedSkills
                          : profile.skills)
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
        ),
        _Panel(
          title: 'Education',
          child: (extractedEducation.isEmpty && profile.education.isEmpty)
              ? const Text('No education has been extracted.')
              : Column(
                  children: extractedEducation.isNotEmpty
                      ? extractedEducation
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.school_outlined,
                                    color: BrandColors.orange),
                                title: Text(item['institution']?.toString() ??
                                    'Institution'),
                                subtitle: Text([
                                  item['degree']?.toString(),
                                  item['fieldOfStudy']?.toString(),
                                ]
                                    .whereType<String>()
                                    .where((value) => value.isNotEmpty)
                                    .join(' · ')),
                              ))
                          .toList()
                      : profile.education
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.school_outlined,
                                    color: BrandColors.orange),
                                title: Text(item.institution),
                                subtitle: Text([
                                  if (item.degree?.isNotEmpty == true)
                                    item.degree!,
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
