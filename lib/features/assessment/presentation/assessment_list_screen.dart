import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/entitlements/module_codes.dart';
import '../../../core/theme/brand_color.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../auth/application/auth_provider.dart';
import '../application/assessment_provider.dart';
import 'widgets/assessment_hero.dart';

class AssessmentListScreen extends ConsumerWidget {
  const AssessmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user?.hasModule(ModuleCodes.hiringStageAssessment) != true) {
      return _AssessmentUpgradeNotice(
        onPlans: () => context.go('/payments'),
      );
    }
    final state = ref.watch(recruiterAssessmentsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            error: error.toString(),
            onRetry: () => ref.invalidate(recruiterAssessmentsProvider)),
        data: (items) {
          final submitted = items.fold<int>(0, (total, item) {
            final analytics = item['analytics'] is Map
                ? Map<String, dynamic>.from(item['analytics'] as Map)
                : const <String, dynamic>{};
            return total +
                (int.tryParse('${analytics['submittedCount'] ?? 0}') ?? 0);
          });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AssessmentHero(
                eyebrow: 'Hiring toolkit',
                title: 'Build a stronger shortlist.',
                description:
                    'Create assessments, invite candidates and review results in one place.',
                metrics: [
                  AssessmentHeroMetric('Assessments', '${items.length}'),
                  AssessmentHeroMetric('Submissions', '$submitted'),
                ],
                action: FilledButton.icon(
                  onPressed: () => context.go('/competency-assessments/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create assessment'),
                  style: FilledButton.styleFrom(
                      backgroundColor: BrandColors.orange,
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(
                        onCreate: () =>
                            context.go('/competency-assessments/new'))
                    : PagedListView<Map<String, dynamic>>(
                        items: items,
                        pageSize: 8,
                        itemBuilder: (context, item, index) => _AssessmentCard(
                          item: item,
                          onTap: () => context.go(
                              '/competency-assessments/${item['_id'] ?? item['id']}'),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AssessmentDetailsScreen extends ConsumerWidget {
  const AssessmentDetailsScreen({super.key, required this.testId});
  final String testId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assessmentRepositoryProvider);
    return FutureBuilder<Map<String, dynamic>>(
      future: repo.getAssessment(testId),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => ref.invalidate(recruiterAssessmentsProvider));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final test = snapshot.data!;
        final analytics =
            Map<String, dynamic>.from(test['analytics'] as Map? ?? const {});
        final candidates = (test['candidates'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final questions = (test['questions'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextButton.icon(
                onPressed: () => context.go('/competency-assessments'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('All assessments')),
            LayoutBuilder(builder: (context, constraints) {
              final title = Text(
                test['title']?.toString() ?? 'Assessment',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy),
              );
              final edit = OutlinedButton.icon(
                onPressed: () =>
                    context.go('/competency-assessments/$testId/edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit assessment'),
              );
              return constraints.maxWidth < 540
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 8), edit],
                    )
                  : Row(
                      children: [Expanded(child: title), edit],
                    );
            }),
            Text(
                '${test['job'] is Map ? test['job']['title'] : ''} · ${test['status'] ?? ''}'),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _MetricTile(
                  label: 'Invited',
                  value: '${analytics['candidateCount'] ?? 0}'),
              _MetricTile(
                  label: 'Started', value: '${analytics['startedCount'] ?? 0}'),
              _MetricTile(
                  label: 'Submitted',
                  value: '${analytics['submittedCount'] ?? 0}'),
              _MetricTile(
                  label: 'Completion',
                  value: '${analytics['completionRate'] ?? 0}%'),
              _MetricTile(
                  label: 'Average score',
                  value: '${analytics['averageScore'] ?? 0}%'),
            ]),
            const SizedBox(height: 22),
            const Text('Candidate results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (candidates.isEmpty)
              const Text('No candidates have been invited yet.'),
            if (candidates.isNotEmpty)
              _PagedAssessmentResults(
                  candidates: candidates, questions: questions),
          ]),
        );
      },
    );
  }
}

class _PagedAssessmentResults extends StatefulWidget {
  const _PagedAssessmentResults(
      {required this.candidates, required this.questions});
  final List<Map<String, dynamic>> candidates;
  final List<Map<String, dynamic>> questions;

  @override
  State<_PagedAssessmentResults> createState() =>
      _PagedAssessmentResultsState();
}

class _PagedAssessmentResultsState extends State<_PagedAssessmentResults> {
  static const _pageSize = 8;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = (widget.candidates.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1).toInt();
    final visible = widget.candidates.skip(page * _pageSize).take(_pageSize);
    return Column(children: [
      for (final candidate in visible)
        _CandidateResult(candidate: candidate, questions: widget.questions),
      if (pageCount > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(
                onPressed:
                    page > 0 ? () => setState(() => _page = page - 1) : null,
                child: const Text('Previous')),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Page ${page + 1} of $pageCount')),
            OutlinedButton(
                onPressed: page + 1 < pageCount
                    ? () => setState(() => _page = page + 1)
                    : null,
                child: const Text('Next')),
          ]),
        ),
    ]);
  }
}

class _CandidateResult extends StatelessWidget {
  const _CandidateResult({required this.candidate, required this.questions});
  final Map<String, dynamic> candidate;
  final List<Map<String, dynamic>> questions;

  @override
  Widget build(BuildContext context) {
    final person = candidate['candidate'] is Map
        ? Map<String, dynamic>.from(candidate['candidate'] as Map)
        : const <String, dynamic>{};
    final answersRaw = candidate['answers'] ?? candidate['responses'];
    final answers = answersRaw is List
        ? answersRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final first = person['firstName']?.toString() ?? '';
    final last = person['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
            child: Text((first.isEmpty ? '?' : first[0]).toUpperCase())),
        title: Text(name.isEmpty ? 'Candidate' : name),
        subtitle: Text(
            '${candidate['status'] ?? 'Invited'} · ${candidate['violationCount'] ?? 0} focus warnings${candidate['timedOut'] == true ? ' · Timed out' : ''}'),
        trailing: Text(candidate['overallScore'] == null
            ? '—'
            : '${candidate['overallScore']}%'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: [
          Wrap(spacing: 16, runSpacing: 8, children: [
            if (person['email'] != null) Text('Email: ${person['email']}'),
            if (candidate['startedAt'] != null)
              Text('Started: ${candidate['startedAt']}'),
            if (candidate['submittedAt'] != null)
              Text('Submitted: ${candidate['submittedAt']}'),
            if (candidate['timeSpentSeconds'] != null)
              Text('Time: ${candidate['timeSpentSeconds']} sec'),
          ]),
          const SizedBox(height: 12),
          if (questions.isEmpty)
            const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Question details are not available for this assessment.'))
          else
            for (var index = 0; index < questions.length; index++)
              _QuestionResult(
                  index: index, question: questions[index], answers: answers),
        ],
      ),
    );
  }
}

class _QuestionResult extends StatelessWidget {
  const _QuestionResult(
      {required this.index, required this.question, required this.answers});
  final int index;
  final Map<String, dynamic> question;
  final List<Map<String, dynamic>> answers;

  @override
  Widget build(BuildContext context) {
    final id = (question['_id'] ?? question['id'] ?? question['questionId'])
        ?.toString();
    final response = answers.cast<Map<String, dynamic>?>().firstWhere(
          (a) =>
              a != null &&
              ((id != null &&
                      (a['questionId'] ??
                                  a['question']?['_id'] ??
                                  a['question']?['id'])
                              ?.toString() ==
                          id) ||
                  (a['questionText']?.toString() ==
                      question['question']?.toString())),
          orElse: () => null,
        );
    final questionText = question['question']?.toString() ??
        question['text']?.toString() ??
        'Question ${index + 1}';
    final yourAnswer = response?['answer'] ??
        response?['response'] ??
        response?['selectedOption'] ??
        response?['text'];
    final correct = question['correctAnswer'] ?? question['answerKey'];
    final isCorrect = response?['isCorrect'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${index + 1}. $questionText',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            'Candidate response: ${yourAnswer?.toString() ?? 'No response recorded'}'),
        if (correct != null) Text('Correct answer: $correct'),
        if (isCorrect != null)
          Text(isCorrect == true ? 'Marked correct' : 'Marked incorrect',
              style: TextStyle(
                  color: isCorrect == true
                      ? Colors.green.shade700
                      : Colors.red.shade700)),
      ]),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final analytics =
        Map<String, dynamic>.from(item['analytics'] as Map? ?? const {});
    final job = item['job'] is Map
        ? Map<String, dynamic>.from(item['job'] as Map)
        : const <String, dynamic>{};
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFF0E8),
            child: Icon(Icons.fact_check_outlined, color: BrandColors.orange)),
        title: Text(item['title']?.toString() ?? 'Assessment',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              '${job['title'] ?? 'Job'} · ${item['assessmentKind'] ?? 'internal'} · ${analytics['candidateCount'] ?? 0} invited · ${analytics['submittedCount'] ?? 0} completed'),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Chip(
              label: Text(item['status']?.toString().toUpperCase() ?? 'DRAFT')),
          const Icon(Icons.chevron_right),
        ]),
        onTap: onTap,
      ),
    );
  }
}

class _AssessmentUpgradeNotice extends StatelessWidget {
  const _AssessmentUpgradeNotice({required this.onPlans});
  final VoidCallback onPlans;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline,
                        size: 38, color: BrandColors.orange),
                    const SizedBox(height: 12),
                    const Text(
                        'Competency assessments are available on Professional and Business.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    FilledButton(
                        onPressed: onPlans,
                        style: FilledButton.styleFrom(
                            backgroundColor: BrandColors.orange),
                        child: const Text('View plans')),
                  ]))),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.assignment_outlined,
            size: 50, color: BrandColors.muted),
        const SizedBox(height: 10),
        const Text('No assessments yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
            'Create a manual assessment or generate a first draft with AI.'),
        const SizedBox(height: 14),
        FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(backgroundColor: BrandColors.orange),
            child: const Text('Create assessment')),
      ]));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ]));
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 170,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(color: BrandColors.muted)),
                    const SizedBox(height: 6),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                  ]))));
}
