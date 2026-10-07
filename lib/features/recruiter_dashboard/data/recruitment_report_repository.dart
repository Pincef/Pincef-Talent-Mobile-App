import 'model/recruitment_report_model.dart';

/// Replace this fixture with the recruitment analytics endpoint when it is available.
class RecruitmentReportRepository {
  Future<RecruitmentReport> loadReport() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return const RecruitmentReport(
      totalApplicants: 42800, avgDaysToFill: 18, pipelineHealth: 94.2, totalHires: 1284,
      sources: [RecruitmentSource('LinkedIn', 42, 0xFFFF7625), RecruitmentSource('Referral Program', 28, 0xFF080D35), RecruitmentSource('Job Boards', 18, 0xFFF6A17A), RecruitmentSource('Direct Sourcing', 12, 0xFF08B765)],
      stages: [FunnelStage('Screening', 2.4, 65, 1402, trend: 1), FunnelStage('Technical Assessment', 5.8, 32, 584, congested: true, trend: 1), FunnelStage('First Interview', 4.6, 50, 348, trend: -1), FunnelStage('Final Interview', 4.1, 48, 216, trend: -1), FunnelStage('Offer Stage', 3.2, 88, 42, trend: 1)],
      dropOffReasons: [DropOffReason('Micro-frontend Architecture Competency Gap', 62, 'Strict filter disqualifies profiles without explicit module federation keywords.'), DropOffReason('Distributed Systems Experience (< 5 yrs)', 48, 'High-scale cloud requirement excludes qualified product managers from fintech apps.'), DropOffReason('Salary Band Disparity', 24, 'Candidate compensation expectations exceed upper tier band by 15–20%.')],
    );
  }
}
