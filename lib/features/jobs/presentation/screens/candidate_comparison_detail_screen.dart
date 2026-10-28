import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../assessment/application/assessment_provider.dart';
import '../../application/job_management_provider.dart';

/// Compares applicants for one selected job by their best graded assessment.
/// The existing assessment creation, invitation, taking, and grading flows
/// remain the source of these results.
class CandidateComparisonDetailScreen extends ConsumerWidget {
  const CandidateComparisonDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(jobId));
    final assessments = ref.watch(recruiterAssessmentsProvider);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 850;
      return SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/candidate-comparison'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All jobs'),
                ),
                const SizedBox(height: 4),
                Text(
                  job.valueOrNull?.title ?? 'Candidate Comparison',
                  style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: BrandColors.navy),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Candidates ranked by their best graded assessment for this job.',
                  style: TextStyle(color: BrandColors.muted, height: 1.45),
                ),
                const SizedBox(height: 22),
                if (assessments.isLoading && assessments.valueOrNull == null)
                  const Center(child: CircularProgressIndicator())
                else if (assessments.hasError)
                  _ComparisonMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load assessment scores',
                    message: assessments.error.toString(),
                    action: TextButton(
                      onPressed: () =>
                          ref.invalidate(recruiterAssessmentsProvider),
                      child: const Text('Retry'),
                    ),
                  )
                else
                  _AssessmentRanking(
                    jobId: jobId,
                    assessments: assessments.valueOrNull ?? const [],
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _AssessmentRanking extends StatelessWidget {
  const _AssessmentRanking({required this.jobId, required this.assessments});
  final String jobId;
  final List<Map<String, dynamic>> assessments;

  List<Map<String, dynamic>> _bestResultsForJob() {
    final bestByCandidate = <String, Map<String, dynamic>>{};
    for (final test in assessments) {
      final job = test['job'];
      if (job is! Map || (job['id'] ?? job['_id']).toString() != jobId) {
        continue;
      }
      final testTitle = (test['title'] ?? 'Assessment').toString();
      for (final raw in test['candidates'] as List? ?? const []) {
        if (raw is! Map) continue;
        final result = Map<String, dynamic>.from(raw);
        final score = result['overallScore'];
        if (result['status']?.toString().toLowerCase() != 'graded' ||
            score is! num) {
          continue;
        }
        final person = result['candidate'];
        if (person is! Map) continue;
        final candidate = Map<String, dynamic>.from(person);
        final id = (candidate['_id'] ?? candidate['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final previous = bestByCandidate[id];
        if (previous == null || score > (previous['overallScore'] as num)) {
          result['candidate'] = candidate;
          result['assessmentTitle'] = testTitle;
          bestByCandidate[id] = result;
        }
      }
    }
    final rows = bestByCandidate.values.toList()
      ..sort((a, b) =>
          (b['overallScore'] as num).compareTo(a['overallScore'] as num));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final results = _bestResultsForJob();
    if (results.isEmpty) {
      return _ComparisonMessage(
        icon: Icons.fact_check_outlined,
        title: 'No graded assessment results yet',
        message:
            'The comparison will rank candidates after an assessment for this job has graded their submissions.',
        action: OutlinedButton.icon(
          onPressed: () => context.go('/jobs/$jobId/candidates'),
          icon: const Icon(Icons.people_outline),
          label: const Text('View applicants'),
        ),
      );
    }
    final average = (results.fold<num>(
                0, (sum, row) => sum + (row['overallScore'] as num)) /
            results.length)
        .round();
    final categories = <String>{};
    for (final result in results) {
      for (final item in result['categoryScores'] as List? ?? const []) {
        if (item is Map && item['category'] != null) {
          categories.add(item['category'].toString());
        }
      }
    }
    final sortedCategories = categories.toList()..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Metric(label: 'Ranked candidates', value: '${results.length}'),
        _Metric(label: 'Average best score', value: '$average%'),
      ]),
      const SizedBox(height: 22),
      const Text('Assessment ranking',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BrandColors.navy)),
      const SizedBox(height: 12),
      for (var index = 0; index < results.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CandidateScoreCard(
            result: results[index],
            rank: index + 1,
            categories: sortedCategories,
          ),
        ),
    ]);
  }
}

class _CandidateScoreCard extends StatelessWidget {
  const _CandidateScoreCard(
      {required this.result, required this.rank, required this.categories});
  final Map<String, dynamic> result;
  final int rank;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final person = Map<String, dynamic>.from(result['candidate'] as Map);
    final name =
        '${person['firstName'] ?? ''} ${person['lastName'] ?? ''}'.trim();
    final scores = <String, num>{};
    for (final item in result['categoryScores'] as List? ?? const []) {
      if (item is Map && item['category'] != null && item['score'] is num) {
        scores[item['category'].toString()] = item['score'] as num;
      }
    }
    final total = (result['overallScore'] as num).round();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFF0E8),
              child: Text('$rank',
                  style: const TextStyle(
                      color: BrandColors.orange, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Candidate' : name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                    Text('Best result: ${result['assessmentTitle']}',
                        style: const TextStyle(
                            fontSize: 12, color: BrandColors.muted)),
                  ]),
            ),
            Text('$total%',
                style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: BrandColors.orange)),
          ]),
          if (scores.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final category in categories)
              if (scores[category] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(
                      width: 150,
                      child: Text(category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: BrandColors.muted)),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (scores[category]!.toDouble() / 100)
                            .clamp(0, 1)
                            .toDouble(),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: const Color(0xFFF0F2F5),
                        color: BrandColors.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 38,
                      child: Text('${scores[category]!.round()}%',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.navy)),
                    ),
                  ]),
                ),
          ],
          if ((result['reportSummary']?.toString().trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(result['reportSummary'].toString(),
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: BrandColors.muted)),
            ),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: BrandColors.navy)),
        ]),
      );
}

class _ComparisonMessage extends StatelessWidget {
  const _ComparisonMessage(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: BrandColors.orange),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: BrandColors.muted, height: 1.45)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}
