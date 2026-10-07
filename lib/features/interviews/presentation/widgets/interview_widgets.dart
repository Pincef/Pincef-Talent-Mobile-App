import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/interview_model.dart';
import '../../application/interview_provider.dart';
import '../interview_room_screen.dart';
import 'interview_theme.dart';
import '../schedule_interview_sheet_screen.dart';

Future<void> openMeeting(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'Couldn\'t open the meeting link');
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
    required this.accent,
    this.dark = false,
  });

  final String title, value, note;
  final IconData icon;
  final Color accent;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? ivNavy : Colors.white,
          border: dark ? null : Border.all(color: ivBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: dark ? Colors.white70 : ivMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Icon(icon, size: 16, color: accent),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: dark ? Colors.white : ivNavy,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: dark ? const Color(0xFFADB7D8) : accent,
                    fontSize: 11)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Agenda card (also reusable for the live-room "Scheduled interviews" list)
// ---------------------------------------------------------------------------
class InterviewAgendaCard extends StatelessWidget {
  const InterviewAgendaCard({super.key, required this.interview, this.onTap});
  final Interview interview;
  final VoidCallback? onTap;

  (String, Color) _tag() {
    final i = interview;
    if (!i.isActive) return (i.status.label.toUpperCase(), ivMuted);
    if (i.isLive) return ('LIVE NOW', ivGreen);
    final mins = i.startsAt.difference(DateTime.now()).inMinutes;
    if (mins >= 0 && mins <= 90) return ('IN $mins MINS', ivOrange);
    return i.status == InterviewStatus.pending
        ? ('AWAITING CONFIRMATION', ivMuted)
        : ('CONFIRMED', ivGreen);
  }

  @override
  Widget build(BuildContext context) {
    final i = interview;
    final (tagText, tagColor) = _tag();
    final highlight = tagColor == ivOrange || tagColor == ivGreen && i.isLive;
    final foot = [
      if (i.aiScore != null) 'Match ${i.aiScore}%',
      if (i.interviewers.length > 1)
        'Panel: ${i.interviewers.map((p) => p.name.split(' ').first).join(', ')}',
    ].join('  ·  ');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF7F1) : Colors.white,
          border:
              Border.all(color: highlight ? const Color(0xFFFFD9C2) : ivBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: ivTag(tagText, tagColor)),
            const Spacer(),
            Text(fmtTime(i.startsAt),
                style: const TextStyle(
                    color: ivNavy, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            IvAvatar(
                name: i.candidate.name,
                url: i.candidate.profileImage,
                radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.candidate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ivNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('${i.jobTitle}  ·  ${i.roundName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: ivMuted, fontSize: 12, height: 1.3)),
                  ]),
            ),
          ]),
          if (foot.isNotEmpty || i.canJoinNow) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Text(foot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ivGreen, fontSize: 11))),
              if (i.canJoinNow)
                FilledButton(
                  onPressed: () => openInterviewRoom(context, i),
                  style: FilledButton.styleFrom(
                      backgroundColor: ivNavy,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6))),
                  child:
                      const Text('Join Call', style: TextStyle(fontSize: 12)),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Details sheet: join / reschedule / cancel / close out
// ---------------------------------------------------------------------------
Future<void> showInterviewDetails(BuildContext context, Interview interview) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _DetailsSheet(interview: interview, host: context),
    );

class _DetailsSheet extends ConsumerStatefulWidget {
  const _DetailsSheet({required this.interview, required this.host});
  final Interview interview;
  final BuildContext host;

  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends ConsumerState<_DetailsSheet> {
  bool _busy = false;

  Future<void> _run(Future<String> Function() job) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final msg = await job();
      nav.pop();
      messenger.showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, errorMessage(e));
    }
  }

  Future<String?> _askReason() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel interview?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('The candidate will be notified by email.'),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Reason (optional)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep interview')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ivRed),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Cancel interview'),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: ivMuted),
          const SizedBox(width: 10),
          SizedBox(
              width: 76,
              child: Text(label,
                  style: const TextStyle(color: ivMuted, fontSize: 12))),
          Expanded(child: value),
        ]),
      );

  Widget _txt(String s) => Text(s,
      style: const TextStyle(
          color: ivNavy, fontSize: 13, fontWeight: FontWeight.w600));

  @override
  Widget build(BuildContext context) {
    final i = widget.interview;
    final actions = ref.read(interviewActionsProvider);
    final color = roundColor(i.roundName);
    final canClose = i.isActive && i.hasStarted;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IvAvatar(
                  name: i.candidate.name,
                  url: i.candidate.profileImage,
                  radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.candidate.name,
                          style: const TextStyle(
                              color: ivNavy,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      if (i.candidate.email.isNotEmpty)
                        Text(i.candidate.email,
                            style:
                                const TextStyle(color: ivMuted, fontSize: 12)),
                    ]),
              ),
              ivTag(i.status.label.toUpperCase(), i.isActive ? color : ivMuted),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            _row(Icons.work_outline, 'Role', _txt(i.jobTitle)),
            _row(Icons.layers_outlined, 'Round',
                _txt('${i.roundName} (round ${i.roundNumber})')),
            _row(
                Icons.event,
                'When',
                _txt(
                    '${fmtLong(i.startsAt)}\n${fmtRange(i.startsAt, i.endsAt)} · ${i.durationMins} min')),
            if (i.interviewers.isNotEmpty)
              _row(Icons.groups_outlined, 'Panel',
                  _txt(i.interviewers.map((p) => p.name).join(', '))),
            if (i.aiScore != null)
              _row(Icons.auto_awesome, 'AI match', _txt('${i.aiScore}%')),
            if (i.meetingUrl != null)
              _row(
                  Icons.link,
                  'Link',
                  InkWell(
                      onTap: () => openMeeting(context, i.meetingUrl!),
                      child: Text(i.meetingUrl!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: ivOrange,
                              fontSize: 13,
                              decoration: TextDecoration.underline)))),
            if (i.notes != null) _row(Icons.notes, 'Notes', _txt(i.notes!)),
            if (i.status == InterviewStatus.pending &&
                i.confirmationExpiresAt != null)
              _row(
                  Icons.hourglass_bottom,
                  'Confirm by',
                  _txt(
                      '${fmtDay(i.confirmationExpiresAt!)}, ${fmtTime(i.confirmationExpiresAt!)}')),
            const SizedBox(height: 14),
            if (i.canJoinNow)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          final host = widget.host;
                          Navigator.pop(context);
                          openInterviewRoom(host, i);
                        },
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Join video call'),
                  style: FilledButton.styleFrom(
                      backgroundColor: ivNavy,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                ),
              ),
            if (i.isActive) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            final host = widget.host;
                            Navigator.pop(context);
                            showScheduleInterview(host, existing: i);
                          },
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final reason = await _askReason();
                            if (reason == null) return;
                            _run(() async {
                              await actions.cancel(i.id, reason: reason);
                              return 'Interview cancelled';
                            });
                          },
                    icon: const Icon(Icons.event_busy, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: ivRed,
                        side: const BorderSide(color: Color(0xFFFDA29B))),
                  ),
                ),
              ]),
            ],
            if (canClose) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await actions.closeOut(
                                  i.id, InterviewStatus.completed);
                              return 'Marked as completed';
                            }),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Mark completed'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await actions.closeOut(
                                  i.id, InterviewStatus.noShow);
                              return 'Marked as no-show';
                            }),
                    icon: const Icon(Icons.person_off_outlined, size: 18),
                    label: const Text('No-show'),
                  ),
                ),
              ]),
            ],
            if (_busy)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(color: ivOrange)),
          ]),
    );
  }
}
