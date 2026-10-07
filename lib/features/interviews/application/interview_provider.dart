import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/interview_model.dart';
import '../data/interview_repository.dart';

typedef DateRange = ({DateTime from, DateTime to});
typedef SlotsQuery = ({
  String applicationId,
  DateTime windowStart,
  DateTime windowEnd,
  int durationMins,
  String? excludeInterviewId,
});

// ---------------------------------------------------------------------------
// Calendar UI state (view mode + focused day)
// ---------------------------------------------------------------------------
enum CalendarMode { month, week, day, list }

class CalendarState {
  const CalendarState({required this.mode, required this.focused});
  final CalendarMode mode;
  final DateTime focused;

  CalendarState copyWith({CalendarMode? mode, DateTime? focused}) =>
      CalendarState(mode: mode ?? this.mode, focused: focused ?? this.focused);
}

class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() =>
      CalendarState(mode: CalendarMode.week, focused: dayOnly(DateTime.now()));

  void setMode(CalendarMode m) => state = state.copyWith(mode: m);
  void focus(DateTime d, {CalendarMode? mode}) =>
      state = state.copyWith(focused: dayOnly(d), mode: mode);
  void today() => state = state.copyWith(focused: dayOnly(DateTime.now()));

  void shift(int dir) {
    final f = state.focused;
    final next = switch (state.mode) {
      CalendarMode.month => DateTime(f.year, f.month + dir, 1),
      CalendarMode.day => addDays(f, dir),
      _ => addDays(f, 7 * dir),
    };
    state = state.copyWith(focused: next);
  }
}

final calendarStateProvider =
    NotifierProvider<CalendarNotifier, CalendarState>(CalendarNotifier.new);

/// Week/day/list fetch the Monday–Monday week; month fetches the whole grid
/// (≤ 42 days, inside the backend's 62-day cap).
final visibleRangeProvider = Provider.autoDispose<DateRange>((ref) {
  final s = ref.watch(calendarStateProvider);
  if (s.mode == CalendarMode.month) {
    final g = monthGridOf(s.focused);
    return (from: g.start, to: addDays(g.start, g.weeks * 7));
  }
  final ws = startOfWeek(s.focused);
  return (from: ws, to: addDays(ws, 7));
});

// ---------------------------------------------------------------------------
// Server data
// ---------------------------------------------------------------------------
final interviewsProvider = FutureProvider.autoDispose
    .family<List<Interview>, DateRange>((ref, range) => ref
        .watch(interviewRepositoryProvider)
        .listInterviews(from: range.from, to: range.to));

/// What the calendar shows: the visible range, minus cancelled interviews
/// (the list endpoint returns them; they no longer occupy a slot).
final visibleInterviewsProvider =
    Provider.autoDispose<AsyncValue<List<Interview>>>((ref) {
  final range = ref.watch(visibleRangeProvider);
  return ref.watch(interviewsProvider(range)).whenData((list) =>
      list.where((i) => i.status != InterviewStatus.cancelled).toList());
});

/// Headline numbers always describe the *real* current week and today,
/// regardless of which week the calendar is browsing.
final interviewStatsProvider =
    FutureProvider.autoDispose<InterviewStats>((ref) {
  final now = DateTime.now();
  final ws = startOfWeek(now);
  final ds = dayOnly(now);
  return ref.watch(interviewRepositoryProvider).stats(
        weekStart: ws,
        weekEnd: addDays(ws, 7),
        dayStart: ds,
        dayEnd: addDays(ds, 1),
      );
});

final schedulableProvider =
    FutureProvider.autoDispose<List<SchedulableApplication>>(
        (ref) => ref.watch(interviewRepositoryProvider).schedulable());

final slotsProvider = FutureProvider.autoDispose
    .family<AvailableSlots, SlotsQuery>(
        (ref, q) => ref.watch(interviewRepositoryProvider).slots(
              applicationId: q.applicationId,
              windowStart: q.windowStart,
              windowEnd: q.windowEnd,
              durationMins: q.durationMins,
              excludeInterviewId: q.excludeInterviewId,
            ));

/// Candidate side (for the candidate app screens).
final myInterviewsProvider = FutureProvider.autoDispose<List<Interview>>(
    (ref) => ref.watch(interviewRepositoryProvider).myInterviews());

// ---------------------------------------------------------------------------
// Mutations — every one refreshes calendar, stats and slots afterwards
// ---------------------------------------------------------------------------
class InterviewActions {
  InterviewActions(this._ref);
  final Ref _ref;

  InterviewRepository get _repo => _ref.read(interviewRepositoryProvider);

  void _refresh() {
    _ref.invalidate(interviewsProvider);
    _ref.invalidate(interviewStatsProvider);
    _ref.invalidate(slotsProvider);
    _ref.invalidate(myInterviewsProvider);
  }

  Future<({Interview interview, bool emailSent})> create(
      CreateInterviewRequest req) async {
    final r = await _repo.createInterview(req);
    _refresh();
    return r;
  }

  Future<({Interview interview, bool? emailSent})> update(
    String id, {
    String? roundName,
    DateTime? startsAt,
    int? durationMins,
    String? meetingUrl,
    String? notes,
  }) async {
    final r = await _repo.updateInterview(id,
        roundName: roundName,
        startsAt: startsAt,
        durationMins: durationMins,
        meetingUrl: meetingUrl,
        notes: notes);
    _refresh();
    return r;
  }

  Future<Interview> cancel(String id, {String? reason}) async {
    final r = await _repo.cancelInterview(id, reason: reason);
    _refresh();
    return r;
  }

  Future<Interview> closeOut(String id, InterviewStatus status) async {
    final r = await _repo.closeOut(id, status);
    _refresh();
    return r;
  }

  Future<Interview> confirm(String id) async {
    final r = await _repo.confirm(id);
    _refresh();
    return r;
  }
}

final interviewActionsProvider =
    Provider<InterviewActions>((ref) => InterviewActions(ref));
