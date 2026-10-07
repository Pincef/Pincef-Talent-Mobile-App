import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/interview_model.dart';
import '../application/interview_provider.dart';
import '../data/interview_repository.dart';
import './widgets/interview_theme.dart';

/// Recruiter's working-hours window the slot search runs over (local time).
/// The backend caps a slot window at 24h, so this is one day at a time.
const _workStartHour = 8;
const _workEndHour = 18;

/// Round names are free text on the backend; these are just quick presets.
const _presets = <(String, int)>[
  ('Initial Screening', 30),
  ('Tech Assessment', 60),
  ('Portfolio Review', 45),
  ('Executive Culture', 45),
];
const _durations = [30, 45, 60, 90];

/// Phones get a bottom sheet, tablets/desktop get a dialog.
/// Pass [existing] to reschedule / edit instead of creating.
Future<void> showScheduleInterview(BuildContext context,
    {Interview? existing}) {
  final narrow = MediaQuery.sizeOf(context).width < 760;
  final panel = ScheduleInterviewPanel(existing: existing);
  if (narrow) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => FractionallySizedBox(heightFactor: .96, child: panel),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
          child: panel),
    ),
  );
}

// What the candidate card needs, whether it came from a schedulable
// application (create) or an existing interview (reschedule).
class _Cand {
  const _Cand(this.name, this.jobTitle, this.image, this.score,
      {this.skills = const [], this.meta = ''});
  final String name, jobTitle, meta;
  final String? image;
  final int? score;
  final List<String> skills;
}

class ScheduleInterviewPanel extends ConsumerStatefulWidget {
  const ScheduleInterviewPanel({super.key, this.existing});
  final Interview? existing;

  @override
  ConsumerState<ScheduleInterviewPanel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<ScheduleInterviewPanel> {
  late final TextEditingController _round;
  late final TextEditingController _link;
  late final TextEditingController _notes;
  late int _duration;
  late DateTime _date;
  SchedulableApplication? _app;
  SlotOption? _slot;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _round = TextEditingController(text: e?.roundName ?? _presets[1].$1);
    _link = TextEditingController(text: e?.meetingUrl ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _duration = e?.durationMins ?? _presets[1].$2;
    _date = dayOnly(e?.startsAt ?? DateTime.now());
  }

  @override
  void dispose() {
    _round.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  SlotsQuery? get _query {
    final appId = widget.existing?.applicationId ?? _app?.applicationId;
    if (appId == null) return null;
    return (
      applicationId: appId,
      windowStart:
          DateTime(_date.year, _date.month, _date.day, _workStartHour).toUtc(),
      windowEnd:
          DateTime(_date.year, _date.month, _date.day, _workEndHour).toUtc(),
      durationMins: _duration,
      excludeInterviewId: widget.existing?.id,
    );
  }

  _Cand? get _cand {
    final e = widget.existing;
    if (e != null) {
      return _Cand(
          e.candidate.name, e.jobTitle, e.candidate.profileImage, e.aiScore);
    }
    final a = _app;
    if (a == null) return null;
    final c = a.candidate;
    return _Cand(
      c.name,
      a.jobTitle,
      c.profileImage,
      a.aiScore,
      skills: c.skills,
      meta: [
        if (c.location != null) c.location!,
        if (c.yearsOfExperience != null)
          '${c.yearsOfExperience} yrs experience',
      ].join('  ·  '),
    );
  }

  void _setDate(DateTime d) => setState(() {
        _date = dayOnly(d);
        _slot = null;
      });

  Future<void> _pickCandidate(List<SchedulableApplication> list) async {
    final picked = await showModalBottomSheet<SchedulableApplication>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .95,
        builder: (_, scroll) => ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final a = list[i];
            return ListTile(
              onTap: () => Navigator.pop(ctx, a),
              leading: IvAvatar(
                  name: a.candidate.name, url: a.candidate.profileImage),
              title: Text(a.candidate.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: ivNavy)),
              subtitle: Text(a.jobTitle),
              trailing: a.aiScore == null
                  ? null
                  : ivTag('${a.aiScore}% match', ivOrange),
            );
          },
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _app = picked;
        _slot = null;
      });
    }
  }

  Future<void> _submit() async {
    final existing = widget.existing;
    final round = _round.text.trim();
    final link = _link.text.trim();
    final notes = _notes.text.trim();

    String? err;
    if (!_editing && _app == null) {
      err = 'Select a candidate first.';
    } else if (round.isEmpty) {
      err = 'Give the round a name.';
    } else if (round.length > 60) {
      err = 'Round name can be at most 60 characters.';
    } else if (!_editing && _slot == null) {
      err = 'Pick a time slot.';
    } else if (_editing &&
        _slot == null &&
        _duration != existing!.durationMins) {
      err = 'Pick a new time slot for the new duration.';
    } else if (link.isNotEmpty) {
      final u = Uri.tryParse(link);
      if (u == null ||
          !(u.isScheme('http') || u.isScheme('https')) ||
          u.host.isEmpty) {
        err = 'Meeting link must be a valid http(s) URL.';
      }
    }
    if (err == null && notes.length > 1000)
      err = 'Notes can be at most 1000 characters.';
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final actions = ref.read(interviewActionsProvider);
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String message;
      if (existing == null) {
        final r = await actions.create(CreateInterviewRequest(
          applicationId: _app!.applicationId,
          roundName: round,
          startsAt: _slot!.startsAt,
          durationMins: _duration,
          meetingUrl: link,
          notes: notes,
        ));
        message = r.emailSent
            ? 'Interview scheduled — invite emailed to the candidate'
            : 'Interview scheduled, but the invite email could not be sent';
      } else {
        final r = await actions.update(
          existing.id,
          roundName: round,
          startsAt: _slot?.startsAt,
          durationMins: _slot == null ? null : _duration,
          meetingUrl: link.isEmpty ? null : link,
          notes: notes.isEmpty ? null : notes,
        );
        message = switch (r.emailSent) {
          true => 'Rescheduled — candidate notified',
          false => 'Rescheduled, but the notification email could not be sent',
          null => 'Interview updated',
        };
      }
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
        if (e is InterviewException && e.isConflict) _slot = null;
      });
      if (e is InterviewException && e.isConflict)
        ref.invalidate(slotsProvider);
    }
  }

  // ------------------------------------------------------------------ UI --

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final left = _leftColumn();
    final right = _rightColumn();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: ivNavy, borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(Icons.calendar_month, color: ivOrange, size: 19)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  _editing
                      ? 'Reschedule Interview'
                      : 'Configure Interview Round',
                  style: const TextStyle(
                      color: ivNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const Text(
                  'Pick a conflict-free time. The candidate is emailed automatically.',
                  style: TextStyle(color: ivMuted, fontSize: 12)),
            ]),
          ),
          IconButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ]),
      ),
      const Divider(height: 20),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: left),
                  const SizedBox(width: 28),
                  Expanded(child: right),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  left,
                  const SizedBox(height: 20),
                  right,
                ]),
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: ivBorder))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: ivRed),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: ivRed, fontSize: 12))),
              ]),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check, size: 18),
              label: Text(_editing ? 'Save changes' : 'Confirm Interview'),
              style: FilledButton.styleFrom(
                  backgroundColor: ivOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _section(String n, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          CircleAvatar(
              radius: 11,
              backgroundColor: ivOrange,
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: ivNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3)),
        ]),
      );

  Widget _leftColumn() {
    final cand = _cand;
    final schedulable = ref.watch(schedulableProvider);

    Widget candidateCard;
    if (cand == null) {
      candidateCard = schedulable.when(
        loading: () => const _Box(child: Text('Loading candidates…')),
        error: (e, _) => _Box(
            child: Row(children: [
          Expanded(
              child:
                  Text(errorMessage(e), style: const TextStyle(color: ivRed))),
          TextButton(
              onPressed: () => ref.invalidate(schedulableProvider),
              child: const Text('Retry')),
        ])),
        data: (list) => list.isEmpty
            ? const _Box(
                child: Text('No candidates are ready to be scheduled yet.',
                    style: TextStyle(color: ivMuted)))
            : InkWell(
                onTap: () => _pickCandidate(list),
                borderRadius: BorderRadius.circular(10),
                child: _Box(
                    child: Row(children: const [
                  Icon(Icons.person_search_outlined, color: ivMuted),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Select a candidate',
                          style: TextStyle(
                              color: ivNavy, fontWeight: FontWeight.w600))),
                  Icon(Icons.keyboard_arrow_down, color: ivMuted),
                ])),
              ),
      );
    } else {
      candidateCard = InkWell(
        onTap: _editing || schedulable.value == null
            ? null
            : () => _pickCandidate(schedulable.value!),
        borderRadius: BorderRadius.circular(10),
        child: _Box(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IvAvatar(name: cand.name, url: cand.image, radius: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cand.name,
                          style: const TextStyle(
                              color: ivNavy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(cand.jobTitle,
                          style:
                              const TextStyle(color: ivOrange, fontSize: 12)),
                    ]),
              ),
              if (cand.score != null)
                ivTag('${cand.score}% AI Match', const Color(0xFFDA672E)),
            ]),
            if (cand.meta.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(cand.meta,
                  style: const TextStyle(color: ivMuted, fontSize: 12)),
            ],
            if (cand.skills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in cand.skills)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE4E7EC),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(s,
                          style: const TextStyle(color: ivNavy, fontSize: 11))),
              ]),
            ],
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('1', 'CANDIDATE & JOB'),
      candidateCard,
      const SizedBox(height: 18),
      _section('2', 'INTERVIEW ROUND'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _presets)
          _Choice(
            title: p.$1,
            sub: '${p.$2} mins',
            selected: _round.text.trim() == p.$1,
            onTap: () => setState(() {
              _round.text = p.$1;
              if (_duration != p.$2) _slot = null;
              _duration = p.$2;
            }),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _round,
        maxLength: 60,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
            labelText: 'Round name',
            border: OutlineInputBorder(),
            isDense: true),
      ),
      const SizedBox(height: 4),
      const Text('Duration',
          style: TextStyle(
              color: ivNavy, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (final d in _durations)
          ChoiceChip(
            label: Text('$d min'),
            selected: _duration == d,
            selectedColor: ivNavy,
            labelStyle: TextStyle(
                color: _duration == d ? Colors.white : ivNavy, fontSize: 12),
            onSelected: (_) => setState(() {
              _duration = d;
              _slot = null;
            }),
          ),
      ]),
      const SizedBox(height: 18),
      _section('3', 'MEETING DETAILS'),
      TextField(
        controller: _link,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
            labelText: 'Meeting link (optional)',
            hintText: 'https://meet.google.com/…',
            prefixIcon: Icon(Icons.link, size: 18),
            border: OutlineInputBorder(),
            isDense: true),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        maxLines: 3,
        maxLength: 1000,
        decoration: const InputDecoration(
            labelText: 'Notes for the candidate (optional)',
            border: OutlineInputBorder(),
            isDense: true),
      ),
    ]);
  }

  Widget _rightColumn() {
    final q = _query;
    final today = dayOnly(DateTime.now());
    final strip = List.generate(14, (i) => addDays(today, i));

    Widget slots;
    if (q == null) {
      slots = const _Box(
          child: Text('Select a candidate to see open time slots.',
              style: TextStyle(color: ivMuted)));
    } else {
      slots = ref.watch(slotsProvider(q)).when(
            loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child:
                    Center(child: CircularProgressIndicator(color: ivOrange))),
            error: (e, _) => _Box(
                child: Row(children: [
              Expanded(
                  child: Text(errorMessage(e),
                      style: const TextStyle(color: ivRed))),
              TextButton(
                  onPressed: () => ref.invalidate(slotsProvider),
                  child: const Text('Retry')),
            ])),
            data: (res) => res.slots.isEmpty
                ? const _Box(
                    child: Text(
                        'No slots left on this day. Try another date or a shorter duration.',
                        style: TextStyle(color: ivMuted)))
                : Column(children: [
                    for (var i = 0; i < res.slots.length; i++)
                      _SlotTile(
                        slot: res.slots[i],
                        recommended: i == res.recommendedIndex,
                        selected: _slot?.startsAt == res.slots[i].startsAt,
                        onTap: res.slots[i].isFree
                            ? () => setState(() => _slot = res.slots[i])
                            : null,
                      ),
                  ]),
          );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _section('4', 'DATE & TIME')),
        IconButton(
          tooltip: 'Pick another date',
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date.isBefore(today) ? today : _date,
              firstDate: today,
              lastDate: addDays(today, 365),
            );
            if (d != null) _setDate(d);
          },
        ),
      ]),
      SizedBox(
        height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: strip.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final d = strip[i];
            final sel = sameDay(d, _date);
            return InkWell(
              onTap: () => _setDate(d),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                    color: sel ? ivOrange : ivSoft,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('E').format(d),
                          style: TextStyle(
                              fontSize: 11,
                              color: sel ? Colors.white : ivMuted)),
                      const SizedBox(height: 2),
                      Text('${d.day}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : ivNavy)),
                    ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: ivSoft, borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          Expanded(
              child: Text('Selected: ${fmtLong(_date)}',
                  style: const TextStyle(color: ivNavy, fontSize: 12))),
          Text(utcLabel(),
              style: const TextStyle(
                  color: ivOrange, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 14),
      const Row(children: [
        Expanded(
            child: Text('Available Time Slots',
                style: TextStyle(
                    color: ivNavy, fontSize: 13, fontWeight: FontWeight.w600))),
        Text('✦ Earliest free slot recommended',
            style: TextStyle(color: ivOrange, fontSize: 11)),
      ]),
      const SizedBox(height: 8),
      slots,
      const SizedBox(height: 16),
    ]);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: ivSoft, borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.title,
      required this.sub,
      required this.selected,
      required this.onTap});
  final String title, sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 128,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: selected ? ivNavy : const Color(0xFFF0F1F3),
              border: selected ? Border.all(color: ivOrange) : null,
              borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: selected ? Colors.white : ivNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                    color: selected ? const Color(0xFFB9C2E2) : ivMuted,
                    fontSize: 11)),
          ]),
        ),
      );
}

class _SlotTile extends StatelessWidget {
  const _SlotTile(
      {required this.slot,
      required this.recommended,
      required this.selected,
      required this.onTap});
  final SlotOption slot;
  final bool recommended, selected;
  final VoidCallback? onTap; // null = conflict, not selectable

  @override
  Widget build(BuildContext context) {
    final busy = !slot.isFree;
    final sub = busy
        ? (slot.reasons.isEmpty ? 'Conflict' : slot.reasons.join('  ·  '))
        : 'No conflicts';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: busy ? .55 : 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: selected ? ivNavy : ivSoft,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(busy ? Icons.block : Icons.access_time,
                  size: 16, color: selected ? ivOrange : ivMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtRange(slot.startsAt, slot.endsAt),
                          style: TextStyle(
                              color: selected ? Colors.white : ivNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(sub,
                          style: TextStyle(
                              color:
                                  selected ? const Color(0xFFBFC6DE) : ivMuted,
                              fontSize: 11)),
                    ]),
              ),
              if (recommended)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: ivOrange,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('RECOMMENDED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)))
              else
                Text(busy ? 'Busy' : 'Free',
                    style: TextStyle(
                        color: selected ? Colors.white70 : ivMuted,
                        fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}
