// Mirrors the backend's interview module (interview.service.ts view shapes).
// Hand-written fromJson on purpose: no build_runner / freezed needed.

enum InterviewStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No-show');

  const InterviewStatus(this.api, this.label);
  final String api; // value the backend sends / expects
  final String label;

  /// Occupies a calendar slot (same rule as ACTIVE_INTERVIEW_STATUSES).
  bool get isActive => this == pending || this == confirmed;

  static InterviewStatus parse(String? v) => InterviewStatus.values
      .firstWhere((s) => s.api == v, orElse: () => InterviewStatus.pending);
}

// ---------------------------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------------------------
Map<String, dynamic> _map(Object? o) =>
    o == null ? <String, dynamic>{} : Map<String, dynamic>.from(o as Map);
DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();
int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;
String? _skillName(Object? s) => s is String
    ? s
    : s is Map
        ? (s['name'] ?? s['skill'] ?? s['label'])?.toString()
        : null;

// ---------------------------------------------------------------------------
// Interview (InterviewView)
// ---------------------------------------------------------------------------
class InterviewPerson {
  const InterviewPerson({
    required this.id,
    required this.name,
    this.email = '',
    this.profileImage,
  });

  final String id;
  final String name;
  final String email;
  final String? profileImage;

  factory InterviewPerson.fromJson(Map<String, dynamic> j) => InterviewPerson(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Unknown',
        email: (j['email'] as String?) ?? '',
        profileImage: j['profileImage'] as String?,
      );
}

class Interview {
  const Interview({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.candidate,
    required this.interviewers,
    required this.roundName,
    required this.roundNumber,
    required this.startsAt,
    required this.endsAt,
    required this.durationMins,
    required this.status,
    this.meetingUrl,
    this.notes,
    this.aiScore,
    this.confirmationExpiresAt,
  });

  final String id;
  final String applicationId;
  final String jobId;
  final String jobTitle;
  final InterviewPerson candidate;
  final List<InterviewPerson> interviewers;
  final String roundName;
  final int roundNumber;
  final DateTime startsAt; // local time (parsed from UTC)
  final DateTime endsAt;
  final int durationMins;
  final InterviewStatus status;
  final String? meetingUrl;
  final String? notes;
  final int? aiScore;
  final DateTime? confirmationExpiresAt;

  bool get isActive => status.isActive;
  bool get hasStarted => !startsAt.isAfter(DateTime.now());
  bool get isLive {
    final now = DateTime.now();
    return isActive && !startsAt.isAfter(now) && endsAt.isAfter(now);
  }

  /// In-app video room is open: 10 min before start until 60 min after the
  /// scheduled end. Must match JOIN_EARLY_MS / JOIN_LATE_MS on the backend.
  static const joinEarly = Duration(minutes: 10);
  static const joinLate = Duration(minutes: 60);
  bool get canJoinNow {
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startsAt.subtract(joinEarly)) &&
        now.isBefore(endsAt.add(joinLate));
  }

  factory Interview.fromJson(Map<String, dynamic> j) => Interview(
        id: j['id'] as String,
        applicationId: j['applicationId'] as String,
        jobId: j['jobId'] as String,
        jobTitle: (j['jobTitle'] as String?) ?? 'Untitled role',
        candidate: InterviewPerson.fromJson(_map(j['candidate'])),
        interviewers: ((j['interviewers'] as List?) ?? [])
            .map((e) => InterviewPerson.fromJson(_map(e)))
            .toList(),
        roundName: j['roundName'] as String,
        roundNumber: _int(j['roundNumber'], 1),
        startsAt: _dt(j['startsAt'])!,
        endsAt: _dt(j['endsAt'])!,
        durationMins: _int(j['durationMins']),
        status: InterviewStatus.parse(j['status'] as String?),
        meetingUrl: (j['meetingUrl'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['meetingUrl'] as String,
        notes: (j['notes'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['notes'] as String,
        aiScore: (j['aiScore'] as num?)?.round(),
        confirmationExpiresAt: _dt(j['confirmationExpiresAt']),
      );
}

// ---------------------------------------------------------------------------
// Stats (GET /interviews/stats)
// ---------------------------------------------------------------------------
class InterviewStats {
  const InterviewStats({
    required this.interviewsThisWeek,
    required this.interviewsLastWeek,
    required this.pendingConfirmation,
    required this.invitesExpiringToday,
    required this.completedRounds,
    required this.completionRate,
    required this.todaySessions,
    required this.nextSessionAt,
  });

  final int interviewsThisWeek;
  final int interviewsLastWeek;
  final int pendingConfirmation;
  final int invitesExpiringToday;
  final int completedRounds; // last 30 days
  final int? completionRate; // null until something has finished
  final int todaySessions;
  final DateTime? nextSessionAt;

  factory InterviewStats.fromJson(Map<String, dynamic> j) => InterviewStats(
        interviewsThisWeek: _int(j['interviewsThisWeek']),
        interviewsLastWeek: _int(j['interviewsLastWeek']),
        pendingConfirmation: _int(j['pendingConfirmation']),
        invitesExpiringToday: _int(j['invitesExpiringToday']),
        completedRounds: _int(j['completedRounds']),
        completionRate: (j['completionRate'] as num?)?.toInt(),
        todaySessions: _int(j['todaySessions']),
        nextSessionAt: _dt(j['nextSessionAt']),
      );
}

// ---------------------------------------------------------------------------
// Schedulable applications (GET /interviews/schedulable)
// ---------------------------------------------------------------------------
class SchedulableCandidate {
  const SchedulableCandidate({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.skills = const [],
    this.yearsOfExperience,
    this.location,
  });

  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final List<String> skills;
  final int? yearsOfExperience;
  final String? location;

  factory SchedulableCandidate.fromJson(Map<String, dynamic> j) =>
      SchedulableCandidate(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Unknown',
        email: (j['email'] as String?) ?? '',
        profileImage: j['profileImage'] as String?,
        skills: ((j['skills'] as List?) ?? [])
            .map(_skillName)
            .whereType<String>()
            .toList(),
        yearsOfExperience: (j['yearsOfExperience'] as num?)?.toInt(),
        location: j['location'] as String?,
      );
}

class SchedulableApplication {
  const SchedulableApplication({
    required this.applicationId,
    required this.status,
    required this.candidate,
    required this.jobId,
    required this.jobTitle,
    this.aiScore,
  });

  final String applicationId;
  final String status;
  final int? aiScore;
  final SchedulableCandidate candidate;
  final String jobId;
  final String jobTitle;

  factory SchedulableApplication.fromJson(Map<String, dynamic> j) {
    final job = _map(j['job']);
    return SchedulableApplication(
      applicationId: j['applicationId'] as String,
      status: (j['status'] as String?) ?? '',
      aiScore: (j['aiScore'] as num?)?.round(),
      candidate: SchedulableCandidate.fromJson(_map(j['candidate'])),
      jobId: (job['id'] as String?) ?? '',
      jobTitle: (job['title'] as String?) ?? 'Untitled role',
    );
  }
}

// ---------------------------------------------------------------------------
// Slots (GET /interviews/slots)
// ---------------------------------------------------------------------------
class SlotOption {
  const SlotOption({
    required this.startsAt,
    required this.endsAt,
    required this.conflicts,
    required this.reasons,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final int conflicts;
  final List<String> reasons;
  bool get isFree => conflicts == 0;

  factory SlotOption.fromJson(Map<String, dynamic> j) => SlotOption(
        startsAt: _dt(j['startsAt'])!,
        endsAt: _dt(j['endsAt'])!,
        conflicts: _int(j['conflicts']),
        reasons: ((j['reasons'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class AvailableSlots {
  const AvailableSlots({required this.slots, required this.recommendedIndex});
  final List<SlotOption> slots;
  final int? recommendedIndex;

  factory AvailableSlots.fromJson(Map<String, dynamic> j) => AvailableSlots(
        slots: ((j['slots'] as List?) ?? [])
            .map((e) => SlotOption.fromJson(_map(e)))
            .toList(),
        recommendedIndex: (j['recommendedIndex'] as num?)?.toInt(),
      );
}

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------
class CreateInterviewRequest {
  const CreateInterviewRequest({
    required this.applicationId,
    required this.roundName,
    required this.startsAt,
    required this.durationMins,
    this.meetingUrl,
    this.notes,
  });

  final String applicationId;
  final String roundName;
  final DateTime startsAt;
  final int durationMins;
  final String? meetingUrl;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'applicationId': applicationId,
        'roundName': roundName,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'durationMins': durationMins,
        // Zod's .optional() rejects null on create, so omit empties.
        if (meetingUrl != null && meetingUrl!.isNotEmpty)
          'meetingUrl': meetingUrl,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'tzOffsetMinutes': localOffsetMinutes(),
      };
}

// ---------------------------------------------------------------------------
// Live video (POST /interviews/:id/join-token)
// ---------------------------------------------------------------------------
class JoinInfo {
  const JoinInfo({
    required this.token,
    required this.url,
    required this.roomName,
    required this.identity,
    required this.role,
    required this.expiresAt,
  });

  final String token;
  final String url; // LiveKit server (wss://...)
  final String roomName;
  final String identity;
  final String role; // 'interviewer' | 'candidate'
  final DateTime expiresAt;

  bool get isInterviewer => role == 'interviewer';

  factory JoinInfo.fromJson(Map<String, dynamic> j) => JoinInfo(
        token: j['token'] as String,
        url: j['url'] as String,
        roomName: j['roomName'] as String,
        identity: j['identity'] as String,
        role: (j['role'] as String?) ?? 'interviewer',
        expiresAt: _dt(j['expiresAt'])!,
      );
}

// ---------------------------------------------------------------------------
// Date helpers (all calendar maths is local; the wire format is UTC)
// ---------------------------------------------------------------------------
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday 00:00 local.
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes east of UTC (Lagos = 60). Only used by the backend to format emails.
int localOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

/// First visible cell and number of week-rows for a month grid.
({DateTime start, int weeks}) monthGridOf(DateTime focused) {
  final first = DateTime(focused.year, focused.month, 1);
  final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
  return (
    start: startOfWeek(first),
    weeks: ((first.weekday - 1 + daysInMonth) / 7).ceil(),
  );
}
