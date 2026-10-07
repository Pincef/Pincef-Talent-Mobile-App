enum JobPublishStatus { active, drafting }

class PriorityJob {
  final String title;
  final String department; // e.g. "Engineering • San Francisco, CA"
  final int applicantCount;
  final int? matchCount; // null when the job has no AI matches yet (e.g. still drafting)
  final JobPublishStatus status;
  final bool isScanning; // AI matching in progress — shown alongside status, not instead of it

  const PriorityJob({
    required this.title,
    required this.department,
    required this.applicantCount,
    this.matchCount,
    required this.status,
    this.isScanning = false,
  });
}

enum ActivityType { application, interview, jobUpdate }

class RecentActivityItem {
  final ActivityType type;
  final String prefixText; // text before the bolded name/title, may be empty
  final String boldText; // e.g. "Sarah Chen", "Marcus Wright", "Product Designer"
  final String suffixText; // text after the bolded name/title, may be empty
  final String timeAgo;

  const RecentActivityItem({
    required this.type,
    this.prefixText = '',
    required this.boldText,
    this.suffixText = '',
    required this.timeAgo,
  });
}

class RecruiterDashboardSummary {
  final String recruiterFirstName;
  final int activeJobs;
  final String activeJobsNote;
  final int newApplicants;
  final String newApplicantsNote;
  final int hiredThisMonth;
  final String hiredThisMonthNote;
  final List<PriorityJob> priorityJobs;
  final List<RecentActivityItem> recentActivity;

  const RecruiterDashboardSummary({
    required this.recruiterFirstName,
    required this.activeJobs,
    required this.activeJobsNote,
    required this.newApplicants,
    required this.newApplicantsNote,
    required this.hiredThisMonth,
    required this.hiredThisMonthNote,
    required this.priorityJobs,
    required this.recentActivity,
  });
}