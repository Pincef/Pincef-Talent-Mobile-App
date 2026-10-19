import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/brand_color.dart';
import '../application/assessment_provider.dart';

class CandidateAssessmentsScreen extends ConsumerWidget {
  const CandidateAssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candidateAssessmentsProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My Assessments',
            style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy)),
        const SizedBox(height: 5),
        const Text(
            'View your assessment invitations, schedules and completed results.'),
        const SizedBox(height: 18),
        Expanded(
            child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error.toString()),
            OutlinedButton(
                onPressed: () => ref.invalidate(candidateAssessmentsProvider),
                child: const Text('Retry'))
          ])),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No assessment invitations yet.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final job = item['job'] is Map
                        ? Map<String, dynamic>.from(item['job'] as Map)
                        : const <String, dynamic>{};
                    final status = item['status']?.toString() ?? 'pending';
                    final available = item['availableUntil']?.toString();
                    return Card(
                        child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF0E8),
                          child: Icon(Icons.assignment_outlined,
                              color: BrandColors.orange)),
                      title: Text(
                          item['title']?.toString() ?? 'Competency assessment',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${job['title'] ?? 'Job'} · ${status == 'submitted' ? 'Awaiting recruiter review' : status}${available == null ? '' : ' · Closes ${_date(available)}'}'),
                      trailing: FilledButton(
                          onPressed: status == 'graded' || status == 'submitted'
                              ? null
                              : () => context.go('/assessments/${item['id']}'),
                          child:
                              Text(status == 'graded' || status == 'submitted'
                                  ? 'Submitted'
                                  : status == 'in_progress'
                                      ? 'Resume'
                                      : status == 'pending'
                                          ? 'Start'
                                          : 'Completed')),
                    ));
                  },
                ),
        )),
      ]),
    );
  }

  static String _date(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    return date == null
        ? raw
        : '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
