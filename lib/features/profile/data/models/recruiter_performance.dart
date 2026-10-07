/// lib/features/profile/data/models/recruiter_performance.dart
///
/// Mirrors GET /api/users/me/performance's response shape.
class RecruiterPerformance {
  final int fillRate; // percentage, 0-100
  final int avgTimeToHireDays;
  final int activeJobs;
  final int hiresMade;

  const RecruiterPerformance({
    required this.fillRate,
    required this.avgTimeToHireDays,
    required this.activeJobs,
    required this.hiresMade,
  });

  factory RecruiterPerformance.fromJson(Map<String, dynamic> json) {
    return RecruiterPerformance(
      fillRate: json['fillRate'] as int? ?? 0,
      avgTimeToHireDays: json['avgTimeToHireDays'] as int? ?? 0,
      activeJobs: json['activeJobs'] as int? ?? 0,
      hiresMade: json['hiresMade'] as int? ?? 0,
    );
  }
}
