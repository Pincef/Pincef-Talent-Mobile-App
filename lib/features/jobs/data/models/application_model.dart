/// Candidate-facing application data — apply flow + "have I already
/// applied" checks. Mirrors application.model.ts's ApplicationStatus enum.
enum ApplicationBackendStatus {
  submitted,
  shortlisted,
  interviewing,
  offered,
  rejected,
  hired,
}

extension ApplicationBackendStatusJson on ApplicationBackendStatus {
  static ApplicationBackendStatus fromJson(String value) => switch (value) {
        'shortlisted' => ApplicationBackendStatus.shortlisted,
        'interviewing' => ApplicationBackendStatus.interviewing,
        'offered' => ApplicationBackendStatus.offered,
        'rejected' => ApplicationBackendStatus.rejected,
        'hired' => ApplicationBackendStatus.hired,
        _ => ApplicationBackendStatus.submitted,
      };

  String get label => switch (this) {
        ApplicationBackendStatus.submitted => 'Submitted',
        ApplicationBackendStatus.shortlisted => 'Shortlisted',
        ApplicationBackendStatus.interviewing => 'Interviewing',
        ApplicationBackendStatus.offered => 'Offered',
        ApplicationBackendStatus.rejected => 'Not selected',
        ApplicationBackendStatus.hired => 'Hired',
      };
}

/// One of the candidate's own applications — enough to know "have I
/// applied to this job" and drive the post-apply confirmation screen.
class ApplicationSummary {
  const ApplicationSummary({
    required this.id,
    required this.jobId,
    required this.status,
    required this.appliedAt,
    this.jobTitle,
    this.companyName,
    this.location,
  });

  final String id;
  final String jobId;
  final ApplicationBackendStatus status;
  final DateTime appliedAt;

  /// Only populated when jobId arrives as a joined object rather than a
  /// bare id string — true for GET /applications/me now that
  /// application.service.ts's getMyApplications populates jobId (and its
  /// companyId) for exactly this screen. Null on any endpoint that still
  /// returns a bare jobId.
  final String? jobTitle;
  final String? companyName;
  final String? location;

  /// application.model.ts's IApplication has no dedicated human-readable
  /// reference number — just the Mongo _id. This derives a short, stable,
  /// display-friendly tag from it for the "Application Submitted" screen.
  /// It's not a real sequential reference a support team could search by;
  /// add a proper field on IApplication if that's actually needed.
  String get referenceNumber {
    final tail = id.length >= 6 ? id.substring(id.length - 6) : id;
    return 'CP-${tail.toUpperCase()}';
  }

  factory ApplicationSummary.fromApiJson(Map<String, dynamic> json) {
    final jobRaw = json['jobId'];
    final jobIsPopulated = jobRaw is Map<String, dynamic>;
    final companyRaw = jobIsPopulated ? jobRaw['companyId'] : null;

    return ApplicationSummary(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      jobId: _extractId(jobRaw),
      status: ApplicationBackendStatusJson.fromJson(
          json['status'] as String? ?? 'submitted'),
      appliedAt: DateTime.tryParse(json['appliedAt'] as String? ?? '') ??
          DateTime.now(),
      jobTitle: jobIsPopulated ? jobRaw['title'] as String? : null,
      location: jobIsPopulated ? jobRaw['location'] as String? : null,
      companyName: companyRaw is Map<String, dynamic>
          ? companyRaw['name'] as String?
          : null,
    );
  }

  /// jobId may arrive as a bare id string or a populated object depending
  /// on the endpoint — handle both rather than assuming one shape. Also
  /// reused by [JobApplicantSummary] below (same library, so the private
  /// static member is visible there too).
  static String _extractId(dynamic value) {
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      return (value['_id'] ?? value['id'] ?? '') as String;
    }
    return '';
  }
}

/// One page of the candidate's own applications. Mirrors
/// application.service.ts's getMyApplications paginated response
/// (applications/total/page/totalPages) — same envelope shape as
/// JobApplicantsPage below, just wrapping ApplicationSummary instead of
/// JobApplicantSummary.
class MyApplicationsPage {
  const MyApplicationsPage({
    required this.applications,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<ApplicationSummary> applications;
  final int total;
  final int page;
  final int totalPages;

  /// The backend now always returns the paginated envelope, but this also
  /// accepts a bare list — the pre-pagination response shape — so this
  /// doesn't hard-break if it's ever pointed at an older deployed backend.
  /// [fallbackPage] is used only in that case, since a bare list carries
  /// no page number of its own.
  factory MyApplicationsPage.fromApiJson(dynamic data,
      {required int fallbackPage}) {
    if (data is List) {
      final applications = data
          .cast<Map<String, dynamic>>()
          .map(ApplicationSummary.fromApiJson)
          .toList();
      return MyApplicationsPage(
        applications: applications,
        total: applications.length,
        page: fallbackPage,
        totalPages: 1,
      );
    }

    final json = data as Map<String, dynamic>;
    final rawApplications = (json['applications'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return MyApplicationsPage(
      applications:
          rawApplications.map(ApplicationSummary.fromApiJson).toList(),
      total: json['total'] as int? ?? rawApplications.length,
      page: json['page'] as int? ?? fallbackPage,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

/// One CV on the candidate's profile — just what the "which CV should we
/// use?" picker needs. Mirrors candidateProfile.model.ts's ICvFile
/// (deliberately a subset, not the full candidate profile shape).
class CvFileOption {
  const CvFileOption({
    required this.publicId,
    required this.originalName,
    required this.uploadedAt,
  });

  final String publicId;
  final String originalName;
  final DateTime uploadedAt;

  factory CvFileOption.fromApiJson(Map<String, dynamic> json) {
    return CvFileOption(
      publicId: json['publicId'] as String? ?? '',
      originalName: json['originalName'] as String? ?? 'CV',
      uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ============================================================
// Recruiter-facing: applicants for one job
// ============================================================

/// The bare candidate fields the recruiter's applicants list actually
/// needs. GET /applications/job/:jobId populates candidateId with the full
/// user document (candidate.model.ts's IUser) — this deliberately only
/// pulls out the handful of fields the UI renders rather than modelling
/// the whole user shape here.
class ApplicantInfo {
  const ApplicantInfo({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.skills = const [],
    this.profileImageUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;

  /// Not present on the candidateId object in the current
  /// GET /applications/job/:jobId payload (only id/firstName/lastName/
  /// email/role/isVerified/etc. come through) — parsed defensively here so
  /// the candidate card's skill tags light up the moment the backend adds
  /// it, without this needing another model change. Empty until then.
  final List<String> skills;

  /// FIX: the candidate's profile photo (candidateProfile.model.ts's
  /// `profileImage.url`) lives on the CandidateProfile document, a
  /// separate collection from the User document that candidateId is
  /// currently populated from on GET /applications/job/:jobId — so this
  /// will be null until the backend's applications query also
  /// joins/populates CandidateProfile.profileImage (or denormalizes the
  /// URL onto the application) and includes it here.
  ///
  /// Parsed defensively for a couple of shapes so it lights up the moment
  /// that backend change lands, without another model change: either a
  /// flat `profileImageUrl` string, or a nested `profileImage: {url,
  /// publicId}` object (the shape CandidateProfile actually stores it in
  /// — see candidateProfile.model.ts's IProfileImage). Null/missing/empty
  /// all mean "no photo" — the UI falls back to the initials avatar.
  final String? profileImageUrl;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final combined = '$f$l';
    return combined.isEmpty ? '?' : combined.toUpperCase();
  }

  factory ApplicantInfo.fromApiJson(Map<String, dynamic> json) {
    return ApplicantInfo(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      skills: (json['skills'] as List?)?.cast<String>() ?? const [],
      profileImageUrl: _extractProfileImageUrl(json),
    );
  }

  static String? _extractProfileImageUrl(Map<String, dynamic> json) {
    final flat = json['profileImageUrl'];
    if (flat is String && flat.isNotEmpty) return flat;

    final nested = json['profileImage'];
    if (nested is Map<String, dynamic>) {
      final url = nested['url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }
}

/// One applicant row on the recruiter's Job Candidates screen. Maps to
/// GET /applications/job/:jobId's per-application shape — candidateId
/// arrives populated (an embedded user object), unlike ApplicationSummary
/// above where jobId is the thing that may or may not be populated.
class JobApplicantSummary {
  const JobApplicantSummary({
    required this.id,
    required this.jobId,
    required this.candidate,
    required this.status,
    required this.appliedAt,
    this.cvUrl,
    this.aiScore,
  });

  final String id;
  final String jobId;
  final ApplicantInfo candidate;
  final ApplicationBackendStatus status;
  final DateTime appliedAt;

  /// Cloudinary URL for the CV submitted with this application. Null is
  /// possible in principle (older applications, or a future no-CV apply
  /// path) even though today's applications always seem to carry one —
  /// the screen should treat it as optional rather than assume it's set.
  final String? cvUrl;

  /// 0–100 match score the backend computes per application (see the
  /// `aiScore` field on the raw GET /applications/job/:jobId response).
  /// Null for any application scored before this field existed — the
  /// screen skips the match-score bar entirely rather than showing 0%.
  final int? aiScore;

  /// Coarse "time ago" label for the card footer. Computed at read time
  /// against DateTime.now(), same approach as ApplicationSummary's
  /// referenceNumber getter above — fine for a label that's re-rendered
  /// on every build rather than cached.
  String get appliedRelativeLabel {
    final diff = DateTime.now().difference(appliedAt);
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'just now';
  }

  factory JobApplicantSummary.fromApiJson(Map<String, dynamic> json) {
    final candidateRaw = json['candidateId'];
    final candidate = candidateRaw is Map<String, dynamic>
        ? ApplicantInfo.fromApiJson(candidateRaw)
        : const ApplicantInfo(
            id: '', firstName: 'Unknown', lastName: 'Candidate', email: '');
    return JobApplicantSummary(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      jobId: ApplicationSummary._extractId(json['jobId']),
      candidate: candidate,
      status: ApplicationBackendStatusJson.fromJson(
          json['status'] as String? ?? 'submitted'),
      appliedAt: DateTime.tryParse(json['appliedAt'] as String? ?? '') ??
          DateTime.now(),
      cvUrl: json['cvUrl'] as String?,
      aiScore: json['aiScore'] as int?,
    );
  }
}

/// One page of a job's applicants — mirrors application.service.ts's
/// getApplicationsForJob response shape (applications/total/page/
/// totalPages) exactly, same pagination envelope as JobBrowseResult on
/// the candidate-facing side.
class JobApplicantsPage {
  const JobApplicantsPage({
    required this.applications,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<JobApplicantSummary> applications;
  final int total;
  final int page;
  final int totalPages;

  factory JobApplicantsPage.fromApiJson(Map<String, dynamic> json) {
    final rawApplications = (json['applications'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return JobApplicantsPage(
      applications:
          rawApplications.map(JobApplicantSummary.fromApiJson).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}
