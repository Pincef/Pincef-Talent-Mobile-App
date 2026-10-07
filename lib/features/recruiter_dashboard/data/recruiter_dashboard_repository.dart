import 'model/recruiter_dashboard_models.dart';

/// Same situation as the candidate DashboardRepository: mocked to match
/// the design so the UI can be built/reviewed now. Swap loadDashboard()
/// for a real endpoint call when the recruiter analytics API exists —
/// the RecruiterDashboardSummary shape stays the same either way.
class RecruiterDashboardRepository {
  Future<RecruiterDashboardSummary> loadDashboard() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return const RecruiterDashboardSummary(
      recruiterFirstName: 'Alex',
      activeJobs: 24,
      activeJobsNote: '+3 from last month',
      newApplicants: 143,
      newApplicantsNote: '42 urgent reviews',
      hiredThisMonth: 25,
      hiredThisMonthNote: '+47% success rate',
      priorityJobs: [
        PriorityJob(
          title: 'Senior Frontend Engineer',
          department: 'Engineering • San Francisco, CA',
          applicantCount: 32,
          matchCount: 12,
          status: JobPublishStatus.active,
        ),
        PriorityJob(
          title: 'Lead Product Designer',
          department: 'Design • Remote',
          applicantCount: 18,
          matchCount: 5,
          status: JobPublishStatus.active,
        ),
        PriorityJob(
          title: 'Solutions Architect',
          department: 'IT Ops • Austin, TX',
          applicantCount: 12,
          status: JobPublishStatus.drafting,
          isScanning: true,
        ),
        PriorityJob(
          title: 'Solutions Architect',
          department: 'IT Ops • Austin, TX',
          applicantCount: 12,
          status: JobPublishStatus.drafting,
          isScanning: true,
        ),
      ],
      recentActivity: [
        RecentActivityItem(
          type: ActivityType.application,
          boldText: 'Sarah Chen',
          suffixText: ' applied for Frontend Engineer. Match score: 94%',
          timeAgo: '2 hours ago',
        ),
        RecentActivityItem(
          type: ActivityType.interview,
          prefixText: 'Interview scheduled with ',
          boldText: 'Marcus Wright',
          suffixText: '.',
          timeAgo: '4 hours ago',
        ),
        RecentActivityItem(
          type: ActivityType.jobUpdate,
          prefixText: 'Job description for ',
          boldText: 'Product Designer',
          suffixText: ' updated.',
          timeAgo: 'Yesterday',
        ),
      ],
    );
  }
}