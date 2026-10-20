import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../application/interview_provider.dart';

class CandidateInterviewsScreen extends ConsumerWidget {
  const CandidateInterviewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myInterviewsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myInterviewsProvider);
        await ref.read(myInterviewsProvider.future);
      },
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Interview and schedule',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Your upcoming interviews and interview details.'),
        const SizedBox(height: 20),
        state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load interviews: $error'),
          data: (interviews) => interviews.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('No interviews scheduled yet.')))
              : Column(
                  children: interviews
                      .map((interview) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.videocam_outlined)),
                              title: Text(interview.jobTitle),
                              subtitle: Text(
                                  '${interview.roundName} · ${DateFormat.yMMMd().add_jm().format(interview.startsAt)}\n${interview.status.label}'),
                              isThreeLine: true,
                            ),
                          ))
                      .toList()),
        ),
      ]),
    );
  }
}
