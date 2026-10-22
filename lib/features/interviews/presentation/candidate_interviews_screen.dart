import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../application/interview_provider.dart';
import '../data/models/interview_model.dart';
import 'interview_room_screen.dart';

class CandidateInterviewsScreen extends ConsumerStatefulWidget {
  const CandidateInterviewsScreen({super.key});

  @override
  ConsumerState<CandidateInterviewsScreen> createState() =>
      _CandidateInterviewsScreenState();
}

class _CandidateInterviewsScreenState
    extends ConsumerState<CandidateInterviewsScreen> {
  Timer? _joinWindowTicker;
  int _page = 0;
  static const _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _joinWindowTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _joinWindowTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(myInterviewsProvider);
    final upcomingCount = state.valueOrNull
            ?.where((interview) =>
                interview.isActive && interview.endsAt.isAfter(DateTime.now()))
            .length ??
        0;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myInterviewsProvider);
        await ref.read(myInterviewsProvider.future);
      },
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF101A3B), Color(0xFF273B68)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1F101A3B),
                  blurRadius: 18,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('YOUR INTERVIEWS',
                        style: TextStyle(
                            color: Color(0xFFFFC58E),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                  ),
                  const SizedBox(height: 14),
                  const Text('A conversation is\nyour next opportunity.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                      'Review the details, prepare, and join when your interview room opens.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          height: 1.4)),
                  const SizedBox(height: 15),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.event_available_outlined,
                        color: Color(0xFFFFC58E), size: 17),
                    const SizedBox(width: 7),
                    Text(
                        '$upcomingCount upcoming ${upcomingCount == 1 ? 'interview' : 'interviews'}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ])),
            const SizedBox(width: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .16))),
              child: const Icon(Icons.video_camera_front_outlined,
                  color: Color(0xFFFFC58E), size: 36),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('Scheduled interviews',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load interviews: $error'),
          data: (interviews) => interviews.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('No interviews scheduled yet.')))
              : Builder(builder: (context) {
                  final pageCount = (interviews.length / _pageSize).ceil();
                  final currentPage =
                      _page.clamp(0, (pageCount - 1).clamp(0, 1 << 30)).toInt();
                  final visible =
                      interviews.skip(currentPage * _pageSize).take(_pageSize);
                  return Column(children: [
                    ...visible.map((interview) {
                      final canJoin = interview.canJoinNow;
                      final nextJoin =
                          interview.startsAt.subtract(Interview.joinEarly);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const CircleAvatar(
                                      backgroundColor: Color(0xFFFFF0E8),
                                      child: Icon(
                                          Icons.video_camera_front_outlined,
                                          color: Color(0xFFDB6B32))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(interview.jobTitle,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700)),
                                        Text(interview.roundName,
                                            style: const TextStyle(
                                                color: Colors.black54)),
                                      ])),
                                  Chip(label: Text(interview.status.label)),
                                ]),
                                const SizedBox(height: 14),
                                Wrap(spacing: 18, runSpacing: 8, children: [
                                  _Detail(
                                      icon: Icons.calendar_today_outlined,
                                      text: DateFormat.yMMMd()
                                          .add_jm()
                                          .format(interview.startsAt)),
                                  _Detail(
                                      icon: Icons.timelapse_outlined,
                                      text:
                                          '${interview.durationMins} minutes'),
                                ]),
                                if (interview.notes?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 12),
                                  Text(interview.notes!,
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                ],
                                const SizedBox(height: 14),
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          canJoin
                                              ? 'Your interview room is open.'
                                              : interview.isActive
                                                  ? 'Join opens ${DateFormat.yMMMd().add_jm().format(nextJoin)}.'
                                                  : 'This interview is ${interview.status.label.toLowerCase()}.',
                                          style: TextStyle(
                                              color: canJoin
                                                  ? Colors.green.shade700
                                                  : Colors.black54))),
                                  if (canJoin)
                                    FilledButton.icon(
                                        onPressed: () => openInterviewRoom(
                                            context, interview),
                                        icon: const Icon(
                                            Icons.video_call_outlined),
                                        label: const Text('Join interview')),
                                ]),
                              ]),
                        ),
                      );
                    }),
                    if (pageCount > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                  onPressed: currentPage > 0
                                      ? () => setState(
                                          () => _page = currentPage - 1)
                                      : null,
                                  child: const Text('Previous')),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                      'Page ${currentPage + 1} of $pageCount')),
                              OutlinedButton(
                                  onPressed: currentPage + 1 < pageCount
                                      ? () => setState(
                                          () => _page = currentPage + 1)
                                      : null,
                                  child: const Text('Next')),
                            ]),
                      ),
                  ]);
                }),
        ),
      ]),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Text(text)
      ]);
}
