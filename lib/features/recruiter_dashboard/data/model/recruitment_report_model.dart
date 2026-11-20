class RecruitmentReport {
  final int totalApplicants;
  final int shortlisted;
  final int rejected;
  final int totalHires;
  final int activeJobs;
  final List<ApplicationTrendPoint> applicationTrend;
  final List<RecruitmentSource> sources;
  final List<FunnelStage> stages;
  final List<DropOffReason> dropOffReasons;
  const RecruitmentReport({
    required this.totalApplicants,
    required this.shortlisted,
    required this.rejected,
    required this.totalHires,
    required this.activeJobs,
    required this.applicationTrend,
    required this.sources,
    required this.stages,
    required this.dropOffReasons,
  });
}

class ApplicationTrendPoint {
  final int year;
  final int month;
  final int count;
  const ApplicationTrendPoint({
    required this.year,
    required this.month,
    required this.count,
  });

  String get label => const [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ][month - 1];
}

class RecruitmentSource {
  final String name;
  final int percent;
  final int colorValue;
  const RecruitmentSource(this.name, this.percent, this.colorValue);
}

class FunnelStage {
  final String name;
  final int volume;
  const FunnelStage(this.name, this.volume);
}

class DropOffReason {
  final String title;
  final int percent;
  final String detail;
  const DropOffReason(this.title, this.percent, this.detail);
}
