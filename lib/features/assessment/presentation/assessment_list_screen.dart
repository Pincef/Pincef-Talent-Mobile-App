import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/entitlements/module_codes.dart';
import '../../../core/theme/brand_color.dart';
import '../../auth/application/auth_provider.dart';
import '../application/assessment_provider.dart';

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
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Competency Assessments',
                        style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                    SizedBox(height: 5),
                    Text(
                        'Create assessments, invite candidates and review their results.',
                        style: TextStyle(color: BrandColors.muted)),
                  ])),
              FilledButton.icon(
                onPressed: () => context.go('/competency-assessments/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create assessment'),
                style:
                    FilledButton.styleFrom(backgroundColor: BrandColors.orange),
              ),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(
                      onCreate: () => context.go('/competency-assessments/new'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _AssessmentCard(
                        item: items[index],
                        onTap: () => context.go(
                            '/competency-assessments/${items[index]['_id'] ?? items[index]['id']}'),
                      ),
                    ),
            ),
          ],
        ),
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
            for (final candidate in candidates)
              Card(
                  child: ListTile(
                leading: CircleAvatar(
                    child: Text('${candidate['candidate']?['firstName'] ?? '?'}'
                        .characters
                        .first
                        .toUpperCase())),
                title: Text(
                    '${candidate['candidate']?['firstName'] ?? ''} ${candidate['candidate']?['lastName'] ?? ''}'
                        .trim()),
                subtitle: Text(
                    '${candidate['status']} · ${candidate['violationCount'] ?? 0} focus warnings${candidate['timedOut'] == true ? ' · Timed out' : ''}'),
                trailing: Text(candidate['overallScore'] == null
                    ? '—'
                    : '${candidate['overallScore']}%'),
              )),
          ]),
        );
      },
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
