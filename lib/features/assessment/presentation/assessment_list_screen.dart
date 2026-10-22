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
        if (snapshot.hasError) {
          return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => ref.invalidate(recruiterAssessmentsProvider));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
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
    final score = candidate['overallScore'];
    final submitted = candidate['submittedAt'] != null ||
        candidate['status']?.toString().toLowerCase() == 'completed';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor: const Color(0xFFFFF0E8),
          child: Text((first.isEmpty ? '?' : first[0]).toUpperCase(),
              style: const TextStyle(
                  color: BrandColors.orange, fontWeight: FontWeight.w800)),
        ),
        title: Text(name.isEmpty ? 'Candidate' : name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ResultTag(
                  label: (candidate['status'] ?? 'Invited').toString(),
                  color:
                      submitted ? const Color(0xFF16794B) : BrandColors.muted,
                  background: submitted
                      ? const Color(0xFFE9F7EF)
                      : const Color(0xFFF1F3F6),
                ),
                Text(
                    '${candidate['violationCount'] ?? 0} focus warnings${candidate['timedOut'] == true ? ' · Timed out' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: BrandColors.muted)),
              ]),
        ),
        trailing: score == null
            ? const Text('—', style: TextStyle(color: BrandColors.muted))
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$score%',
                    style: const TextStyle(
                        color: BrandColors.orange,
                        fontWeight: FontWeight.w800))),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EBF0))),
            child: Wrap(spacing: 24, runSpacing: 14, children: [
              if (person['email'] != null)
                _CandidateMeta(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: '${person['email']}'),
              if (candidate['startedAt'] != null)
                _CandidateMeta(
                    icon: Icons.play_circle_outline,
                    label: 'Started',
                    value: _formatResultDate(candidate['startedAt'])),
              if (candidate['submittedAt'] != null)
                _CandidateMeta(
                    icon: Icons.task_alt,
                    label: 'Submitted',
                    value: _formatResultDate(candidate['submittedAt'])),
              if (candidate['timeSpentSeconds'] != null)
                _CandidateMeta(
                    icon: Icons.timer_outlined,
                    label: 'Time spent',
                    value: '${candidate['timeSpentSeconds']} sec'),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Icon(Icons.fact_check_outlined,
                size: 19, color: BrandColors.orange),
            const SizedBox(width: 8),
            const Text('Response review',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const Spacer(),
            Text('${answers.length} responses',
                style: const TextStyle(color: BrandColors.muted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          if (questions.isEmpty)
            const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'Question details are not available for this assessment.'),
                ))
          else
            _PagedQuestionResults(questions: questions, answers: answers),
        ],
      ),
    );
  }
}

class _PagedQuestionResults extends StatefulWidget {
  const _PagedQuestionResults({required this.questions, required this.answers});
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> answers;

  @override
  State<_PagedQuestionResults> createState() => _PagedQuestionResultsState();
}

class _PagedQuestionResultsState extends State<_PagedQuestionResults> {
  static const _pageSize = 4;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageCount = (widget.questions.length / _pageSize).ceil();
    final page = _page.clamp(0, pageCount - 1).toInt();
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, widget.questions.length);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var index = start; index < end; index++)
        _QuestionResult(
            index: index,
            question: widget.questions[index],
            answers: widget.answers),
      if (pageCount > 1)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [
            Text('Questions ${start + 1}–$end of ${widget.questions.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.muted)),
            const Spacer(),
            IconButton(
                tooltip: 'Previous questions',
                visualDensity: VisualDensity.compact,
                onPressed:
                    page > 0 ? () => setState(() => _page = page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Text('${page + 1} / $pageCount',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
            IconButton(
                tooltip: 'Next questions',
                visualDensity: VisualDensity.compact,
                onPressed: page + 1 < pageCount
                    ? () => setState(() => _page = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right)),
          ]),
        ),
    ]);
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
    final hasResponse =
        yourAnswer != null && yourAnswer.toString().trim().isNotEmpty;
    final answerColor = isCorrect == true
        ? const Color(0xFF16794B)
        : isCorrect == false
            ? const Color(0xFFB54735)
            : BrandColors.navy;
    final answerBackground = isCorrect == true
        ? const Color(0xFFE9F7EF)
        : isCorrect == false
            ? const Color(0xFFFFF0ED)
            : const Color(0xFFF4F6FA);
    final points = response?['pointsAwarded'];
    final maxPoints = question['points'] ?? question['marks'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EBF0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080E1A3D), blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: BrandColors.orange, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(questionText,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: BrandColors.navy))),
          if (isCorrect != null)
            _ResultTag(
              label: isCorrect == true ? 'Correct' : 'Incorrect',
              color: answerColor,
              background: answerBackground,
              icon: isCorrect == true
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
            )
          else if (correct == null)
            const _ResultTag(
                label: 'Review',
                color: Color(0xFF8A5700),
                background: Color(0xFFFFF5D9),
                icon: Icons.rate_review_outlined),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;
          final responsePanel = _AnswerPanel(
            label: 'CANDIDATE RESPONSE',
            value: hasResponse ? yourAnswer.toString() : 'No response recorded',
            icon: hasResponse
                ? Icons.chat_bubble_outline
                : Icons.do_not_disturb_alt_outlined,
            color: answerColor,
            background: answerBackground,
          );
          final correctPanel = correct != null
              ? _AnswerPanel(
                  label: 'CORRECT ANSWER',
                  value: correct.toString(),
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF16794B),
                  background: const Color(0xFFE9F7EF))
              : const _AnswerPanel(
                  label: 'GRADING',
                  value: 'This response is reviewed manually.',
                  icon: Icons.rate_review_outlined,
                  color: Color(0xFF8A5700),
                  background: Color(0xFFFFF5D9));
          if (stacked) {
            return Column(children: [
              responsePanel,
              const SizedBox(height: 10),
              correctPanel
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: responsePanel),
            const SizedBox(width: 12),
            Expanded(child: correctPanel),
          ]);
        }),
        if (points != null || maxPoints != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.stars_outlined,
                size: 16, color: BrandColors.orange),
            const SizedBox(width: 6),
            Text(
                'Points awarded: ${points ?? '—'}${maxPoints != null ? ' / $maxPoints' : ''}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.muted)),
          ]),
        ],
      ]),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.background});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w800,
                    color: color))
          ]),
          const SizedBox(height: 9),
          SelectableText(value,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: BrandColors.navy)),
        ]),
      );
}

class _ResultTag extends StatelessWidget {
  const _ResultTag(
      {required this.label,
      required this.color,
      required this.background,
      this.icon});
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4)
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _CandidateMeta extends StatelessWidget {
  const _CandidateMeta(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 205,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: BrandColors.orange),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: BrandColors.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.navy)),
              ])),
        ]),
      );
}

String _formatResultDate(dynamic value) {
  final date = DateTime.tryParse(value.toString());
  if (date == null) return value.toString();
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
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
