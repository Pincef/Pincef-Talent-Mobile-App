enum ApplicationStage { applied, screening, technical, finalStage }

class CandidateDashboardApplication {
  final String jobTitle;
  final String company;
  final String appliedLabel; // e.g. "Applied 4 days ago"
  final String statusLabel; // e.g. "INTERVIEWING", "APPLICATION SENT"
  final ApplicationStage currentStage;
  final double progressPercent; // 0.0 - 1.0

  const CandidateDashboardApplication({
    required this.jobTitle,
    required this.company,
    required this.appliedLabel,
    required this.statusLabel,
    required this.currentStage,
    required this.progressPercent,
  });
}

enum UploadStatus { parsing, ready }

class RecentUpload {
  final String fileName;
  final String uploadedLabel; // e.g. "Uploaded today, 10:45 AM"
  final UploadStatus status;

  const RecentUpload({
    required this.fileName,
    required this.uploadedLabel,
    required this.status,
  });
}

class JobMatch {
  final String title;
  final String company;
  final String workMode; // e.g. "Remote", "Hybrid"
  final String salaryRange;
  final int matchPercent;
  final List<String> tags;

  const JobMatch({
    required this.title,
    required this.company,
    required this.workMode,
    required this.salaryRange,
    required this.matchPercent,
    required this.tags,
  });
}

class WorkExperienceSummary {
  final num yearsOfExperience;
  final String title;
  final String company;
  final String period; // e.g. "2020 - Present"
  final String description;

  const WorkExperienceSummary({
    required this.yearsOfExperience,
    required this.title,
    required this.company,
    required this.period,
    required this.description,
  });
}

class DashboardSummary {
  final List<String> careerHighlights;
  final List<String> coreStrengths;
  final WorkExperienceSummary workExperience;
  final List<CandidateDashboardApplication> applications;
  final List<RecentUpload> recentUploads;
  final List<JobMatch> jobMatches;
  final String workspaceTip;

  const DashboardSummary({
    required this.careerHighlights,
    required this.coreStrengths,
    required this.workExperience,
    required this.applications,
    required this.recentUploads,
    required this.jobMatches,
    required this.workspaceTip,
  });
}
