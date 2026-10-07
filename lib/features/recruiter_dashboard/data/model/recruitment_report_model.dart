class RecruitmentReport {
  final int totalApplicants;
  final int avgDaysToFill;
  final double pipelineHealth;
  final int totalHires;
  final List<RecruitmentSource> sources;
  final List<FunnelStage> stages;
  final List<DropOffReason> dropOffReasons;
  const RecruitmentReport({required this.totalApplicants, required this.avgDaysToFill, required this.pipelineHealth, required this.totalHires, required this.sources, required this.stages, required this.dropOffReasons});
}

class RecruitmentSource {
  final String name;
  final int percent;
  final int colorValue;
  const RecruitmentSource(this.name, this.percent, this.colorValue);
}

class FunnelStage {
  final String name;
  final double days;
  final int passThrough;
  final int volume;
  final bool congested;
  final int trend; // -1 falling, 0 stable, 1 rising
  const FunnelStage(this.name, this.days, this.passThrough, this.volume, {this.congested = false, this.trend = 0});
}

class DropOffReason {
  final String title;
  final int percent;
  final String detail;
  const DropOffReason(this.title, this.percent, this.detail);
}
