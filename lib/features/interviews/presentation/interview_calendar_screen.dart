import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/models/interview_model.dart';
import '../application/interview_provider.dart';
import './widgets/interview_theme.dart';
import './widgets/interview_widgets.dart';
import './schedule_interview_sheet_screen.dart';

/// Catches a synchronous throw from anything `build()` touches — most
/// importantly the external date/grid/format helpers (`monthGridOf`,
/// `roundColor`, `fmtDay`/`fmtLong`/`fmtRange`, `startOfWeek`, `addDays`,
/// `sameDay`, `errorMessage`, ...) that this screen calls inline rather
/// than through a child widget. Those calls run as plain Dart function
/// calls inside whichever `build()` invokes them, so if one throws (e.g.
/// on an edge case in empty or oddly-shaped data), the exception
/// propagates straight out of that `build()` — Flutter can't isolate it
/// to a small subtree the way it can for a child widget's own `build()`.
/// Wrapping the risky part of each `build()` in this turns that into a
/// calm fallback message instead of losing the whole screen.
Widget _guard(Widget Function() build,
    {String message = 'Could not display this section.'}) {
  try {
    return build();
  } catch (e, st) {
    debugPrint('InterviewCalendarScreen guard caught: $e\n$st');
    return _Empty(message);
  }
}

/// Same idea as [_guard], for a single small piece inside a tightly sized
/// grid — one day cell, one event chip, one legend dot. Falling back to
/// the full [_Empty] placeholder there (fixed vertical padding + icon)
/// would visually break the grid's uniform sizing worse than just
/// omitting that one item, so this fails silently instead.
Widget _guardCompact(Widget Function() build) {
  try {
    return build();
  } catch (e, st) {
    debugPrint('InterviewCalendarScreen guard (compact) caught: $e\n$st');
    return const SizedBox.shrink();
  }
}

/// Recruiter "Interview & Calendar Schedule" screen, wired to /interviews.
/// ≥ 900px: week/day time-grid + agenda side panel.
/// < 900px (phones): day strip + agenda cards, which is far easier to use
/// than a 5-column time grid on a 390px screen.
class InterviewCalendarScreen extends ConsumerWidget {
  const InterviewCalendarScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final range = ref.read(visibleRangeProvider);
    ref.invalidate(interviewsProvider);
    ref.invalidate(interviewStatsProvider);
    try {
      await ref.read(interviewsProvider(range).future);
    } catch (_) {/* the error state renders itself */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calendarStateProvider);
    final data = ref.watch(visibleInterviewsProvider);

    return Scaffold(
      backgroundColor: ivCanvas,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 900;
          final pad = wide ? 24.0 : 14.0;
          // AsyncValue.value is only ever null while loading/erroring —
          // never because the server legitimately returned zero rows — so
          // this already covers "no interviews yet" correctly on its own.
          final interviews = data.value ?? const <Interview>[];
          final calendar = _CalendarCard(cal: cal, data: data, wide: wide);

          return RefreshIndicator(
            color: ivOrange,
            onRefresh: () => _refresh(ref),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(wide: wide),
                        const SizedBox(height: 16),
                        _StatsRow(wide: wide),
                        const SizedBox(height: 14),
                        if (wide)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: calendar),
                                const SizedBox(width: 14),
                                SizedBox(
                                    width: 300,
                                    child: _AgendaPanel(
                                        day: cal.focused,
                                        interviews: interviews)),
                              ])
                        else
                          calendar,
                        const SizedBox(height: 10),
                        _Legend(interviews: interviews),
                      ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header + stats
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final title =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('Interview & Calendar Schedule',
          style: TextStyle(
              color: ivNavy, fontSize: 24, fontWeight: FontWeight.w700)),
      SizedBox(height: 4),
      Text(
          'Coordinate candidate rounds and keep recruiter availability in sync.',
          style: TextStyle(color: ivMuted, fontSize: 13)),
    ]);
    final button = FilledButton.icon(
      onPressed: () => showScheduleInterview(context),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Schedule Interview'),
      style: FilledButton.styleFrom(
          backgroundColor: ivOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Dashboard  /  Interviews & Calendar',
          style: TextStyle(color: ivMuted, fontSize: 12)),
      const SizedBox(height: 8),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: title),
          button,
        ])
      else ...[
        title,
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: button),
      ],
    ]);
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.wide});
  final bool wide;

  static const _nbsp = '\u00A0';

  String _delta(InterviewStats s) {
    final d = s.interviewsThisWeek - s.interviewsLastWeek;
    if (d > 0) return '↗ +$d vs last week';
    if (d < 0) return '↘ $d vs last week';
    return 'Same as last week';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _guard(() {
        final s = ref.watch(interviewStatsProvider).value;

        final cards = <Widget>[
          StatCard(
              title: 'Interviews This Week',
              value: s?.interviewsThisWeek.toString() ?? '–',
              note: s == null ? _nbsp : _delta(s),
              icon: Icons.calendar_month_outlined,
              accent: ivGreen),
          StatCard(
              title: 'Pending Confirmation',
              value: s?.pendingConfirmation.toString() ?? '–',
              note: s == null
                  ? _nbsp
                  : s.invitesExpiringToday > 0
                      ? '${s.invitesExpiringToday} invite${s.invitesExpiringToday == 1 ? '' : 's'} expire today'
                      : 'None expiring today',
              icon: Icons.access_time,
              accent: ivOrange),
          StatCard(
              title: 'Completed Rounds',
              value: s?.completedRounds.toString() ?? '–',
              note: s == null
                  ? _nbsp
                  : s.completionRate != null
                      ? '${s.completionRate}% completion · 30 days'
                      : 'Last 30 days',
              icon: Icons.task_alt,
              accent: ivGreen),
          StatCard(
              title: "Today's Focus",
              value: s == null
                  ? '–'
                  : '${s.todaySessions} Session${s.todaySessions == 1 ? '' : 's'}',
              note: s == null
                  ? _nbsp
                  : s.nextSessionAt != null
                      ? 'Next: ${fmtTime(s.nextSessionAt!)}'
                      : 'Nothing else today',
              icon: Icons.event_available_outlined,
              accent: ivOrange,
              dark: true),
        ];

        if (wide) {
          return Row(children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 10),
            ]
          ]);
        }
        return LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in cards) SizedBox(width: w, child: c),
          ]);
        });
      }, message: 'Stats are unavailable right now.');
}

// ---------------------------------------------------------------------------
// Calendar card (toolbar + body per mode)
// ---------------------------------------------------------------------------
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard(
      {required this.cal, required this.data, required this.wide});
  final CalendarState cal;
  final AsyncValue<List<Interview>> data;
  final bool wide;

  String _label() {
    try {
      final f = cal.focused;
      switch (cal.mode) {
        case CalendarMode.month:
          return DateFormat('MMMM y').format(f);
        case CalendarMode.day:
          return DateFormat('EEE, MMM d, y').format(f);
        case CalendarMode.week:
        case CalendarMode.list:
          final ws = startOfWeek(f);
          final we = addDays(ws, 6);
          return ws.month == we.month
              ? '${DateFormat('MMM d').format(ws)} – ${we.day}, ${we.year}'
              : '${DateFormat('MMM d').format(ws)} – ${DateFormat('MMM d, y').format(we)}';
      }
    } catch (e) {
      debugPrint('_CalendarCard._label failed: $e');
      // Falls back to a plain, helper-free rendering of the focused date
      // so the toolbar never goes blank even if the formatters above throw.
      final f = cal.focused;
      return '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
    }
  }

  List<DateTime> _weekDays(List<Interview> list) {
    try {
      final ws = startOfWeek(cal.focused);
      final weekend = list.any((i) =>
          i.startsAt.weekday >= DateTime.saturday &&
          !i.startsAt.isBefore(ws) &&
          i.startsAt.isBefore(addDays(ws, 7)));
      return List.generate(weekend ? 7 : 5, (k) => addDays(ws, k));
    } catch (e) {
      debugPrint('_CalendarCard._weekDays failed: $e');
      // No startOfWeek/addDays involved — guaranteed not to throw, so the
      // week grid still renders (just anchored on today) instead of the
      // whole card disappearing.
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      return List.generate(5, (k) => today.add(Duration(days: k)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(calendarStateProvider.notifier);

    final toolbar = Column(children: [
      Row(children: [
        OutlinedButton(
          onPressed: notifier.today,
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: ivBorder),
              foregroundColor: ivNavy),
          child: const Text('Today', style: TextStyle(fontSize: 12)),
        ),
        IconButton(
            onPressed: () => notifier.shift(-1),
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact),
        IconButton(
            onPressed: () => notifier.shift(1),
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact),
        const SizedBox(width: 4),
        Expanded(
            child: Text(_label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: ivNavy, fontSize: 15, fontWeight: FontWeight.w700))),
        if (data.isLoading)
          const SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: ivOrange)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.circle, size: 8, color: ivGreen),
        const SizedBox(width: 5),
        Text(_guardedUtcLabel(),
            style: const TextStyle(fontSize: 11, color: ivMuted)),
        const Spacer(),
        _ViewToggle(mode: cal.mode, onChanged: (m) => notifier.setMode(m)),
      ]),
    ]);

    final Widget body = data.when(
      loading: () => const SizedBox(
          height: 260,
          child: Center(child: CircularProgressIndicator(color: ivOrange))),
      error: (e, _) => _ErrorBox(
          message: _guardedErrorMessage(e),
          onRetry: () => ref.invalidate(interviewsProvider)),
      data: (list) {
        switch (cal.mode) {
          case CalendarMode.month:
            return _guard(
                () => _MonthGrid(
                    focused: cal.focused, interviews: list, wide: wide),
                message: 'Could not display the month view.');
          case CalendarMode.list:
            return _guard(() => _AgendaList(interviews: list),
                message: 'Could not display the list view.');
          case CalendarMode.week:
            return wide
                ? _guard(
                    () => _TimeGrid(
                        days: _weekDays(list),
                        interviews: list,
                        focused: cal.focused,
                        onDayTap: notifier.focus),
                    message: 'Could not display the week grid.')
                : Column(children: [
                    _guard(
                        () => _DayStrip(focused: cal.focused, interviews: list),
                        message: 'Could not display the day strip.'),
                    const SizedBox(height: 12),
                    _guard(() => _DayList(day: cal.focused, interviews: list),
                        message: 'Could not display this day.'),
                  ]);
          case CalendarMode.day:
            return wide
                ? _guard(
                    () => _TimeGrid(
                        days: [cal.focused],
                        interviews: list,
                        focused: cal.focused,
                        onDayTap: notifier.focus),
                    message: 'Could not display the day grid.')
                : Column(children: [
                    _guard(
                        () => _DayStrip(focused: cal.focused, interviews: list),
                        message: 'Could not display the day strip.'),
                    const SizedBox(height: 12),
                    _guard(() => _DayList(day: cal.focused, interviews: list),
                        message: 'Could not display this day.'),
                  ]);
        }
      },
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: ivBorder),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [toolbar, const SizedBox(height: 12), body]),
    );
  }

  String _guardedUtcLabel() {
    try {
      return utcLabel();
    } catch (e) {
      debugPrint('utcLabel failed: $e');
      return '';
    }
  }

  String _guardedErrorMessage(Object e) {
    try {
      return errorMessage(e);
    } catch (_) {
      return "Couldn't load interviews. Pull down to retry.";
    }
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});
  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            border: Border.all(color: ivBorder),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in CalendarMode.values)
            InkWell(
              onTap: () => onChanged(m),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: m == mode ? ivNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(m.name[0].toUpperCase() + m.name.substring(1),
                    style: TextStyle(
                        fontSize: 12,
                        color: m == mode ? Colors.white : ivMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(children: [
          const Icon(Icons.cloud_off_outlined, color: ivMuted, size: 32),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ivMuted)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          const Icon(Icons.event_available_outlined, color: ivBorder, size: 36),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ivMuted, fontSize: 13)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Phone: day strip + day agenda
// ---------------------------------------------------------------------------
class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.focused, required this.interviews});
  final DateTime focused;
  final List<Interview> interviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _guard(() {
        final ws = startOfWeek(focused);
        return Row(children: [
          for (var k = 0; k < 7; k++)
            Builder(builder: (_) {
              return _guardCompact(() {
                final d = addDays(ws, k);
                final sel = sameDay(d, focused);
                final n =
                    interviews.where((i) => sameDay(i.startsAt, d)).length;
                final isToday = sameDay(d, DateTime.now());
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        ref.read(calendarStateProvider.notifier).focus(d),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                          color: sel ? ivOrange : ivSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !sel
                              ? Border.all(color: ivOrange)
                              : null),
                      child: Column(children: [
                        Text(DateFormat('E').format(d).substring(0, 2),
                            style: TextStyle(
                                fontSize: 11,
                                color: sel ? Colors.white : ivMuted)),
                        const SizedBox(height: 2),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : ivNavy)),
                        const SizedBox(height: 4),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: n == 0
                                    ? Colors.transparent
                                    : (sel ? Colors.white : ivOrange))),
                      ]),
                    ),
                  ),
                );
              });
            }),
        ]);
      }, message: 'Could not display the week strip.');
}

class _DayList extends StatelessWidget {
  const _DayList({required this.day, required this.interviews});
  final DateTime day;
  final List<Interview> interviews;

  @override
  Widget build(BuildContext context) => _guard(() {
        final items = interviews.where((i) => sameDay(i.startsAt, day)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_guardedFmtLong(day),
              style: const TextStyle(
                  color: ivNavy, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const _Empty('No interviews on this day')
          else
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _guard(
                    () => InterviewAgendaCard(
                        interview: i,
                        onTap: () => showInterviewDetails(context, i)),
                    message: 'Could not display this interview.'),
              ),
        ]);
      }, message: 'Could not display this day.');

  String _guardedFmtLong(DateTime d) {
    try {
      return fmtLong(d);
    } catch (e) {
      debugPrint('fmtLong failed: $e');
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }
}

// ---------------------------------------------------------------------------
// List mode: everything in the visible week, grouped by day
// ---------------------------------------------------------------------------
class _AgendaList extends StatelessWidget {
  const _AgendaList({required this.interviews});
  final List<Interview> interviews;

  @override
  Widget build(BuildContext context) => _guard(() {
        if (interviews.isEmpty) {
          return const _Empty('No interviews in this week');
        }
        final sorted = [...interviews]
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final children = <Widget>[];
        DateTime? last;
        for (final i in sorted) {
          if (last == null || !sameDay(last, i.startsAt)) {
            children.add(Padding(
              padding: EdgeInsets.only(top: last == null ? 0 : 10, bottom: 8),
              child: Text(_guardedFmtLong(i.startsAt),
                  style: const TextStyle(
                      color: ivNavy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ));
            last = i.startsAt;
          }
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _guard(
                () => InterviewAgendaCard(
                    interview: i,
                    onTap: () => showInterviewDetails(context, i)),
                message: 'Could not display this interview.'),
          ));
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children);
      }, message: 'Could not display the list view.');

  String _guardedFmtLong(DateTime d) {
    try {
      return fmtLong(d);
    } catch (e) {
      debugPrint('fmtLong failed: $e');
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }
}

// ---------------------------------------------------------------------------
// Wide: week/day time grid with positioned events
// ---------------------------------------------------------------------------
class _Placed {
  _Placed(this.interview, this.lane);
  final Interview interview;
  final int lane;
}

class _TimeGrid extends StatelessWidget {
  const _TimeGrid({
    required this.days,
    required this.interviews,
    required this.focused,
    required this.onDayTap,
  });

  final List<DateTime> days;
  final List<Interview> interviews;
  final DateTime focused;
  final ValueChanged<DateTime> onDayTap;

  static const double rowH = 64, gutter = 56;

  @override
  Widget build(BuildContext context) => _guard(() {
        final inView = interviews
            .where((i) => days.any((d) => sameDay(d, i.startsAt)))
            .toList();

        // Default 9–5, stretched to fit anything outside it. Bounded so a
        // malformed timestamp can't collapse the grid to zero height or
        // (less likely, but just as crash-prone downstream) make it
        // negative — DateTime.hour is always 0..23 so no need to clamp
        // that, just the derived end-of-day hour and the final span.
        var startHour = 9, endHour = 17;
        for (final i in inView) {
          final sh = i.startsAt.hour;
          if (sh < startHour) startHour = sh;
          var eh = i.endsAt.hour + (i.endsAt.minute > 0 ? 1 : 0);
          if (eh > 24) eh = 24;
          if (eh > endHour) endHour = eh;
        }
        final hours = endHour > startHour ? endHour - startHour : 1;

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(children: [
            Row(children: [
              const SizedBox(width: gutter),
              for (final d in days)
                Expanded(
                  child: InkWell(
                    onTap: () => onDayTap(d),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sameDay(d, focused)
                            ? const Color(0xFFFFF3EB)
                            : const Color(0xFFF7F9FC),
                        border: const Border(left: BorderSide(color: ivBorder)),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('EEE').format(d),
                                style: const TextStyle(
                                    fontSize: 11, color: ivMuted)),
                            Text('${d.day}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: sameDay(d, focused)
                                        ? ivOrange
                                        : ivNavy)),
                          ]),
                    ),
                  ),
                ),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: gutter,
                height: hours * rowH,
                child: Stack(children: [
                  for (var h = 0; h < hours; h++)
                    Positioned(
                      top: h * rowH + 4,
                      left: 0,
                      right: 6,
                      child: Text(
                          DateFormat('h a')
                              .format(DateTime(2000, 1, 1, startHour + h)),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF98A2B3))),
                    ),
                ]),
              ),
              for (final d in days)
                Expanded(
                  child: _guardCompact(
                    () => _DayColumn(
                      day: d,
                      startHour: startHour,
                      hours: hours,
                      items:
                          inView.where((i) => sameDay(i.startsAt, d)).toList(),
                    ),
                  ),
                ),
            ]),
          ]),
        );
      }, message: 'Could not display the schedule for this range.');
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.startHour,
    required this.hours,
    required this.items,
  });
  final DateTime day;
  final int startHour, hours;
  final List<Interview> items;

  @override
  Widget build(BuildContext context) => _guard(() {
        // Company-wide calendar: different recruiters can overlap, so lay
        // overlapping interviews side by side instead of stacking them.
        final sorted = [...items]
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final laneEnds = <DateTime>[];
        final placed = <_Placed>[];
        for (final i in sorted) {
          var lane = laneEnds.indexWhere((e) => !e.isAfter(i.startsAt));
          if (lane == -1) {
            laneEnds.add(i.endsAt);
            lane = laneEnds.length - 1;
          } else {
            laneEnds[lane] = i.endsAt;
          }
          placed.add(_Placed(i, lane));
        }
        final lanes = laneEnds.isEmpty ? 1 : laneEnds.length;

        final now = DateTime.now();
        final nowTop =
            ((now.hour - startHour) * 60 + now.minute) / 60 * _TimeGrid.rowH;
        final showNow = sameDay(day, now) &&
            nowTop >= 0 &&
            nowTop <= hours * _TimeGrid.rowH;

        return Container(
          height: hours * _TimeGrid.rowH,
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: ivBorder))),
          child: LayoutBuilder(builder: (context, box) {
            final laneW = box.maxWidth / lanes;
            return Stack(children: [
              for (var h = 0; h < hours; h++)
                Positioned(
                    top: h * _TimeGrid.rowH,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: const ColoredBox(color: ivBorder)),
              for (final p in placed)
                // Guarded per-event: one malformed interview (a bad round
                // name tripping up roundColor, say) just skips its own
                // chip instead of blanking the whole day column.
                _guardCompact(() {
                  final i = p.interview;
                  final top =
                      ((i.startsAt.hour - startHour) * 60 + i.startsAt.minute) /
                          60 *
                          _TimeGrid.rowH;
                  final h =
                      (i.durationMins / 60 * _TimeGrid.rowH).clamp(34.0, 600.0);
                  final color = roundColor(i.roundName);
                  return Positioned(
                    top: top + 1,
                    height: h - 2,
                    left: p.lane * laneW + 2,
                    width: laneW - 4,
                    child: InkWell(
                      onTap: () => showInterviewDetails(context, i),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          border:
                              Border(left: BorderSide(color: color, width: 3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(i.candidate.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11))),
                                    if (i.status == InterviewStatus.pending)
                                      Icon(Icons.schedule,
                                          size: 11, color: color),
                                  ]),
                                  if (h >= 48)
                                    Text(i.roundName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: ivMuted, fontSize: 10)),
                                  if (h >= 60)
                                    Text(_guardedFmtRange(i.startsAt, i.endsAt),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: ivMuted, fontSize: 10)),
                                ]),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              if (showNow)
                Positioned(
                    top: nowTop,
                    left: 0,
                    right: 0,
                    height: 2,
                    child: const ColoredBox(color: ivRed)),
            ]);
          }),
        );
      }, message: 'Could not display this day.');

  String _guardedFmtRange(DateTime a, DateTime b) {
    try {
      return fmtRange(a, b);
    } catch (e) {
      debugPrint('fmtRange failed: $e');
      return '';
    }
  }
}

// ---------------------------------------------------------------------------
// Month grid
// ---------------------------------------------------------------------------
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid(
      {required this.focused, required this.interviews, required this.wide});
  final DateTime focused;
  final List<Interview> interviews;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _guard(() {
        final g = monthGridOf(focused);
        final cellH = wide ? 92.0 : 58.0;
        // monthGridOf is expected to always produce at least one week, but
        // guard it anyway so an edge case (e.g. a month boundary bug)
        // degrades to "no grid" instead of a crash.
        final weeks = g.weeks < 1 ? 1 : g.weeks;

        return Column(children: [
          Row(children: [
            for (final d in const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun'
            ])
              Expanded(
                  child: Center(
                      child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(wide ? d : d.substring(0, 1),
                    style: const TextStyle(fontSize: 11, color: ivMuted)),
              ))),
          ]),
          for (var w = 0; w < weeks; w++)
            Row(children: [
              for (var k = 0; k < 7; k++)
                Expanded(
                  child: _guardCompact(() {
                    final d = addDays(g.start, w * 7 + k);
                    final inMonth = d.month == focused.month;
                    final items = interviews
                        .where((i) => sameDay(i.startsAt, d))
                        .toList();
                    final isToday = sameDay(d, DateTime.now());
                    final sel = sameDay(d, focused);
                    return InkWell(
                      onTap: () => ref
                          .read(calendarStateProvider.notifier)
                          .focus(d, mode: CalendarMode.day),
                      child: Container(
                        height: cellH,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFFFF3EB) : null,
                          border: Border.all(color: ivBorder, width: .5),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isToday ? ivOrange : null),
                                child: Text('${d.day}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isToday
                                            ? Colors.white
                                            : inMonth
                                                ? ivNavy
                                                : const Color(0xFFB1BAC7))),
                              ),
                              const Spacer(),
                              if (items.isNotEmpty)
                                wide
                                    ? Text(
                                        '${items.length} interview${items.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: ivOrange,
                                            fontWeight: FontWeight.w600))
                                    : Row(children: [
                                        for (final i in items.take(3))
                                          Container(
                                              margin: const EdgeInsets.only(
                                                  right: 3),
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color:
                                                      roundColor(i.roundName))),
                                      ]),
                            ]),
                      ),
                    );
                  }),
                ),
            ]),
        ]);
      }, message: 'Could not display the month view.');
}

// ---------------------------------------------------------------------------
// Agenda side panel (wide) + legend
// ---------------------------------------------------------------------------
class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel({required this.day, required this.interviews});
  final DateTime day;
  final List<Interview> interviews;

  @override
  Widget build(BuildContext context) => _guard(() {
        final items = interviews.where((i) => sameDay(i.startsAt, day)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final isToday = sameDay(day, DateTime.now());

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: ivBorder),
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.circle, size: 9, color: ivOrange),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${isToday ? "Today's Agenda" : 'Agenda'} (${items.length})',
                      style: const TextStyle(
                          color: ivNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700))),
              Text(_guardedFmtDay(day),
                  style: const TextStyle(color: ivMuted, fontSize: 11)),
            ]),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _Empty('Nothing scheduled')
            else
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _guard(
                      () => InterviewAgendaCard(
                          interview: i,
                          onTap: () => showInterviewDetails(context, i)),
                      message: 'Could not display this interview.'),
                ),
          ]),
        );
      }, message: 'Could not display the agenda.');

  String _guardedFmtDay(DateTime d) {
    try {
      return fmtDay(d);
    } catch (e) {
      debugPrint('fmtDay failed: $e');
      return '';
    }
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.interviews});
  final List<Interview> interviews;

  @override
  Widget build(BuildContext context) => _guardCompact(() {
        final names =
            <String>{for (final i in interviews) i.roundName}.take(6).toList();
        if (names.isEmpty) return const SizedBox.shrink();
        return Wrap(spacing: 16, runSpacing: 6, children: [
          for (final n in names)
            _guardCompact(
              () => Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 9, color: roundColor(n)),
                const SizedBox(width: 5),
                Text(n, style: const TextStyle(color: ivMuted, fontSize: 11)),
              ]),
            ),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule, size: 12, color: ivMuted),
            SizedBox(width: 4),
            Text('Awaiting candidate confirmation',
                style: TextStyle(color: ivMuted, fontSize: 11)),
          ]),
        ]);
      });
}
