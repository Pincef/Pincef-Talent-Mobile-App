/// Backend-aligned job status (mirrors job.model.ts JobStatus). Keep this in
/// sync with the API — do not invent client-only states here.
enum JobBackendStatus { draft, published, closed }

extension JobBackendStatusJson on JobBackendStatus {
  String toJson() => switch (this) {
        JobBackendStatus.draft => 'draft',
        JobBackendStatus.published => 'published',
        JobBackendStatus.closed => 'closed',
      };

  static JobBackendStatus fromJson(String value) => switch (value) {
        'published' => JobBackendStatus.published,
        'closed' => JobBackendStatus.closed,
        _ => JobBackendStatus.draft,
      };
}

/// UI-facing status used by the pipeline cards. Derived from
/// [JobBackendStatus] — `active` = published, `drafting` = draft,
/// `closed` = closed. There is deliberately no "scanning" value: that would
/// represent an AI-matching state that has no backend field yet. If/when a
/// matching service exists, surface it as a separate computed flag (see
/// [JobPosting.isScanning]) rather than folding it into status.
enum JobPipelineStatus { active, drafting, closed }

JobPipelineStatus pipelineStatusFrom(JobBackendStatus status) =>
    switch (status) {
      JobBackendStatus.published => JobPipelineStatus.active,
      JobBackendStatus.draft => JobPipelineStatus.drafting,
      JobBackendStatus.closed => JobPipelineStatus.closed,
    };

/// Valid values for [JobDraft.educationLevel] — mirrors the backend's
/// IJob.educationLevel enum (job.model.ts / job.service.ts). Keep in sync
/// if that enum changes. Keys are the human-readable dropdown labels,
/// values are what actually gets sent in the payload.
const kEducationLevels = <String, String>{
  'High School': 'high_school',
  'Associate Degree': 'associate',
  "Bachelor's Degree": 'bachelors',
  "Master's Degree": 'masters',
  'Doctorate': 'doctorate',
};

/// Data collected across the post-job form. Mirrors the fields
/// job.model.ts / job.service.ts actually persist and validate against —
/// keep both sides in sync when either changes.
///
/// `id` is null until the job is first saved; every subsequent save call
/// must carry it so updates target the same job instead of creating a
/// new one.
class JobDraft {
  const JobDraft({
    this.id,
    this.title,
    this.description,
    this.employmentType,
    this.workplaceType,
    this.location,
    this.minimumSalary,
    this.maximumSalary,
    this.currency,
    this.requiredSkills = const [],
    this.minYearsOfExperience,
    this.educationLevel,
    this.requiresManagementExperience = false,
    this.applicationDeadline,
    this.aiRanking = false,
    this.aiSummary = false,
  });

  final String? id;

  // Basic Information
  final String? title;
  final String? employmentType; // full_time | part_time | contract | internship
  // workplaceType (on_site/hybrid/remote) is collected by the form but is
  // not sent until the backend DTO and model support it.
  final String? workplaceType;
  final String? location;
  final double? minimumSalary;
  final double? maximumSalary;
  final String? currency;

  // Description
  final String? description;

  // Experience & Requirements
  final List<String> requiredSkills;
  final int? minYearsOfExperience;
  final String?
      educationLevel; // high_school | associate | bachelors | masters | doctorate
  final bool requiresManagementExperience;
  final DateTime? applicationDeadline;
  final bool aiRanking;
  final bool aiSummary;

  /// Fields job.service.ts requires before it will allow publishing.
  /// Mirrors REQUIRED_FOR_PUBLISH on the backend — keep in sync.
  List<String> missingForPublish() {
    final missing = <String>[];
    if (title == null || title!.trim().isEmpty) missing.add('title');
    if (description == null || description!.trim().isEmpty) {
      missing.add('description');
    }
    if (employmentType == null) missing.add('employmentType');
    if (minYearsOfExperience == null) missing.add('minYearsOfExperience');
    if (educationLevel == null) missing.add('educationLevel');
    if (requiredSkills.isEmpty) missing.add('requiredSkills');
    if ((aiRanking || aiSummary) && applicationDeadline == null) {
      missing.add('applicationDeadline');
    }
    return missing;
  }

  bool get isReadyToPublish => missingForPublish().isEmpty;

  JobDraft copyWith({
    String? id,
    String? title,
    String? description,
    String? employmentType,
    String? workplaceType,
    String? location,
    double? minimumSalary,
    double? maximumSalary,
    String? currency,
    List<String>? requiredSkills,
    int? minYearsOfExperience,
    String? educationLevel,
    bool? requiresManagementExperience,
    DateTime? applicationDeadline,
    bool? aiRanking,
    bool? aiSummary,
  }) =>
      JobDraft(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        employmentType: employmentType ?? this.employmentType,
        workplaceType: workplaceType ?? this.workplaceType,
        location: location ?? this.location,
        minimumSalary: minimumSalary ?? this.minimumSalary,
        maximumSalary: maximumSalary ?? this.maximumSalary,
        currency: currency ?? this.currency,
        requiredSkills: requiredSkills ?? this.requiredSkills,
        minYearsOfExperience: minYearsOfExperience ?? this.minYearsOfExperience,
        educationLevel: educationLevel ?? this.educationLevel,
        requiresManagementExperience:
            requiresManagementExperience ?? this.requiresManagementExperience,
        applicationDeadline: applicationDeadline ?? this.applicationDeadline,
        aiRanking: aiRanking ?? this.aiRanking,
        aiSummary: aiSummary ?? this.aiSummary,
      );

  /// Payload shape sent to the API — keys match job.service.ts's JobInput.
  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (employmentType != null) 'employmentType': employmentType,
        if (location != null) 'location': location,
        if (minimumSalary != null) 'minSalary': minimumSalary,
        if (maximumSalary != null) 'maxSalary': maximumSalary,
        if (currency != null) 'currency': currency,
        if (requiredSkills.isNotEmpty) 'requiredSkills': requiredSkills,
        if (minYearsOfExperience != null)
          'minYearsOfExperience': minYearsOfExperience,
        if (educationLevel != null) 'educationLevel': educationLevel,
        'requiresManagementExperience': requiresManagementExperience,
        if (applicationDeadline != null)
          'applicationDeadline': applicationDeadline!.toUtc().toIso8601String(),
        if (aiRanking || aiSummary)
          'aiConfig': {'ranking': aiRanking, 'summary': aiSummary},
      };
}

class JobPosting {
  const JobPosting({
    required this.id,
    required this.title,
    required this.location,
    required this.department,
    required this.workMode,
    required this.status,
    this.applicantCount, // null -> shown as "–"
    this.matchQuality, // null -> shown as "N/A"
    this.isScanning = false,
    this.createdAt,
  });

  /// Required for routing to edit/publish/close actions — the previous
  /// version of this model had no id, which made those actions impossible
  /// to wire up.
  final String id;

  final String title;
  final String location;
  final String department;
  final String workMode;
  final JobPipelineStatus status;
  final int? applicantCount;
  final int? matchQuality;

  /// Whether this (published) job currently has an AI-matching pass in
  /// flight. This is NOT sourced from Job.status — there is no backend
  /// field for it yet. Wire this to a real matching-service field once
  /// one exists; until then it defaults to false everywhere.
  final bool isScanning;
  final DateTime? createdAt;

  /// Maps a raw job object from GET /jobs/mine (job.controller.ts's
  /// listMyCompanyJobs, wrapping job.service.ts's JobWithStats) into the
  /// shape this screen renders.
  ///
  /// `department` and `workMode` still have no backing field on IJob
  /// (workMode is the workplaceType gap noted on JobDraft; department
  /// doesn't exist on the schema at all) — both stay placeholdered rather
  /// than guessed. `applicantCount`/`avgMatchQuality` now come from
  /// job.service.ts's per-job Application aggregation, so they're read
  /// straight off the response instead of being hardcoded null.
  factory JobPosting.fromApiJson(Map<String, dynamic> json) {
    final backendStatus =
        JobBackendStatusJson.fromJson(json['status'] as String? ?? 'draft');
    return JobPosting(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      title: json['title'] as String? ?? 'Untitled role',
      location: json['location'] as String? ?? 'Not specified',
      department: '—', // TODO: no field on IJob yet
      workMode: '—', // TODO: workplaceType isn't persisted yet — see JobDraft
      status: pipelineStatusFrom(backendStatus),
      applicantCount: (json['applicantCount'] as num?)?.toInt(),
      matchQuality: (json['avgMatchQuality'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(
        (json['publishedAt'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }
}

class PipelineSummary {
  const PipelineSummary({
    required this.openRoles,
    required this.totalApplicants,
    required this.avgMatchQuality,
    required this.regionsCount,
  });

  final int openRoles;
  final int totalApplicants;
  final int avgMatchQuality;
  final int regionsCount;
}

class HiringEfficiency {
  const HiringEfficiency({
    required this.growthPercent,
    required this.timeToFillDeltaDays,
    required this.recentHiresCount,
  });

  final int growthPercent;
  final int timeToFillDeltaDays;
  final int recentHiresCount;
}

class JobManagementSummary {
  const JobManagementSummary({
    required this.pipeline,
    required this.efficiency,
    required this.postings,
    required this.activeTabCount,
    required this.pendingTabCount,
    required this.closedTabCount,
    required this.totalActivePostingsCount,
    required this.currentPage,
    required this.totalPages,
    required this.monthlyPublishedCount,
  });

  final PipelineSummary pipeline;
  final HiringEfficiency efficiency;

  /// Postings for the currently-shown tab — filtered client-side, since
  /// GET /jobs/mine has no status/pagination query params yet (only the
  /// public GET / route accepts page/limit/search/location).
  final List<JobPosting> postings;

  final int activeTabCount;
  final int pendingTabCount;
  final int closedTabCount;
  final int totalActivePostingsCount;
  final int currentPage;
  final int totalPages;
  final int monthlyPublishedCount;

  /// Builds the whole summary from GET /jobs/mine's flat job list, since
  /// that's the only data the backend currently provides for this screen.
  ///
  /// Assumptions worth revisiting:
  /// - "Pending" has no backend equivalent (JobStatus is only
  ///   draft/published/closed) — mapped to draft here. Swap this or drop
  ///   the Pending tab if that's not what you want it to mean.
  /// - `totalApplicants` is the sum of each job's `applicantCount` (now
  ///   real, via job.service.ts's Application aggregation).
  /// - `avgMatchQuality` averages `matchQuality` across only the jobs that
  ///   have one (i.e. have at least one scored application) — jobs with no
  ///   scored applicants don't drag the average toward zero. Rounds to 0
  ///   when no jobs have a score yet.
  /// - Everything in [HiringEfficiency] still needs a real analytics
  ///   endpoint (period-over-period comparisons, not just current totals)
  ///   that doesn't exist in job.service.ts yet — zeroed out rather than
  ///   faked until that exists.
  /// - `regionsCount` is derived from distinct non-empty `location`
  ///   strings across all jobs, since the backend doesn't compute it.
  /// - No server-side pagination on /jobs/mine yet, so currentPage/
  ///   totalPages are always 1 for now.
  factory JobManagementSummary.fromJobs(
    List<JobPosting> allPostings,
    JobPipelineStatus selectedTab,
  ) {
    final activeCount =
        allPostings.where((j) => j.status == JobPipelineStatus.active).length;
    final pendingCount =
        allPostings.where((j) => j.status == JobPipelineStatus.drafting).length;
    final closedCount =
        allPostings.where((j) => j.status == JobPipelineStatus.closed).length;
    final regions = allPostings
        .map((j) => j.location.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .length;

    final totalApplicants =
        allPostings.fold<int>(0, (sum, job) => sum + (job.applicantCount ?? 0));

    final scoredPostings =
        allPostings.where((job) => job.matchQuality != null).toList();
    final avgMatchQuality = scoredPostings.isEmpty
        ? 0
        : (scoredPostings.fold<int>(0, (sum, job) => sum + job.matchQuality!) /
                scoredPostings.length)
            .round();

    return JobManagementSummary(
      pipeline: PipelineSummary(
        openRoles: activeCount,
        totalApplicants: totalApplicants,
        avgMatchQuality: avgMatchQuality,
        regionsCount: regions,
      ),
      efficiency: const HiringEfficiency(
        growthPercent: 0,
        timeToFillDeltaDays: 0,
        recentHiresCount: 0,
      ),
      postings: allPostings
          .where((j) => j.status == selectedTab)
          .toList(growable: false),
      activeTabCount: activeCount,
      pendingTabCount: pendingCount,
      closedTabCount: closedCount,
      totalActivePostingsCount: allPostings.length,
      currentPage: 1,
      totalPages: 1,
      monthlyPublishedCount: allPostings.where((job) {
        if (job.status == JobPipelineStatus.drafting || job.createdAt == null) {
          return false;
        }
        final now = DateTime.now();
        final date = job.createdAt!.toLocal();
        return date.year == now.year && date.month == now.month;
      }).length,
    );
  }
}

// ============================================================
// Candidate-facing: Browse Jobs
// ============================================================

/// A single job as rendered on the candidate Browse Jobs screen. Maps the
/// same raw Job document GET /jobs (job.service.ts's listPublishedJobs)
/// already returns for the public browse endpoint — no new listing route
/// needed, just a candidate-shaped view of the same data.
class JobListing {
  const JobListing({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.employmentType,
    required this.tags,
    this.minSalary,
    this.maxSalary,
    this.currency,
    this.matchScore,
    this.isSaved = false,
  });

  final String id;
  final String title;
  final String companyName;
  final String location;

  /// Raw backend value (full_time | part_time | contract | internship) —
  /// use [employmentTypeLabel] for display.
  final String? employmentType;

  /// Rendered as the small pill tags on each card. Sourced from
  /// requiredSkills — there's no separate "tags"/category concept on IJob.
  final List<String> tags;

  final double? minSalary;
  final double? maxSalary;
  final String? currency;

  /// AI fit score for *this candidate* against *this job*, 0-100. There is
  /// no backend endpoint that produces this for browsing yet —
  /// CandidateJobAnalysis (candidateJobAnalysis.model.ts) is recruiter-
  /// triggered, and only after the candidate has already applied (see
  /// candidateProfile.service.ts's assertCandidateApplied). Showing a
  /// candidate their fit score *before* they apply needs a separate,
  /// candidate-facing endpoint — likely reusing aiMatcher.matchCandidateToJob
  /// without that gate. Stays null until that exists; the UI shows nothing
  /// rather than a fabricated number.
  final int? matchScore;

  /// Client-only "saved/bookmarked" state — there's no saved-jobs endpoint
  /// yet, so this doesn't persist across sessions or devices. Swap for a
  /// real field once one exists.
  final bool isSaved;

  JobListing copyWith({bool? isSaved}) => JobListing(
        id: id,
        title: title,
        companyName: companyName,
        location: location,
        employmentType: employmentType,
        tags: tags,
        minSalary: minSalary,
        maxSalary: maxSalary,
        currency: currency,
        matchScore: matchScore,
        isSaved: isSaved ?? this.isSaved,
      );

  static const _employmentTypeLabels = {
    'full_time': 'Full-time',
    'part_time': 'Part-time',
    'contract': 'Contract',
    'internship': 'Internship',
  };

  String get employmentTypeLabel =>
      _employmentTypeLabels[employmentType] ?? '—';

  static const _currencySymbols = {
    'USD': '\$',
    'NGN': '₦',
    'EUR': '€',
    'GBP': '£'
  };

  /// e.g. "\$180k - \$220k / year" — mirrors the mockup's job card format.
  /// Falls back gracefully when only one bound is set (recruiters aren't
  /// required to set both) or neither is.
  String get salaryRangeLabel {
    if (minSalary == null && maxSalary == null) return 'Salary not disclosed';
    final symbol = _currencySymbols[(currency ?? 'USD').toUpperCase()] ??
        '${currency ?? 'USD'} ';
    String fmt(double v) =>
        v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
    if (minSalary != null && maxSalary != null) {
      return '$symbol${fmt(minSalary!)} - $symbol${fmt(maxSalary!)} / year';
    }
    return '$symbol${fmt(minSalary ?? maxSalary!)}+ / year';
  }

  /// Maps a raw job object from GET /jobs. job.service.ts's
  /// listPublishedJobs calls `.populate('companyId')`, so companyId arrives
  /// as an embedded object (company.model.ts's ICompany), not a bare id.
  factory JobListing.fromApiJson(Map<String, dynamic> json) {
    final company = json['companyId'];
    final companyName = company is Map<String, dynamic>
        ? (company['name'] as String? ?? 'Unknown company')
        : 'Unknown company';

    return JobListing(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      title: json['title'] as String? ?? 'Untitled role',
      companyName: companyName,
      location: json['location'] as String? ?? 'Not specified',
      employmentType: json['employmentType'] as String?,
      tags: (json['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      minSalary: (json['minSalary'] as num?)?.toDouble(),
      maxSalary: (json['maxSalary'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      // No backend field for this yet — see the doc comment on matchScore.
      matchScore: null,
    );
  }
}

/// One page of the candidate Browse Jobs list — mirrors job.service.ts's
/// PaginatedJobs shape (jobs/total/page/totalPages) exactly.
class JobBrowseResult {
  const JobBrowseResult({
    required this.jobs,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<JobListing> jobs;
  final int total;
  final int page;
  final int totalPages;

  factory JobBrowseResult.fromApiJson(Map<String, dynamic> json) {
    final rawJobs = (json['jobs'] as List).cast<Map<String, dynamic>>();
    return JobBrowseResult(
      jobs: rawJobs.map(JobListing.fromApiJson).toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

/// Search/filter state for the candidate Browse Jobs screen. `search` and
/// `location` map straight to job.dto.ts's listJobsQuerySchema;
/// `employmentType` is the small addition made there alongside this screen
/// so the Full-time/Contract-style chips filter server-side instead of
/// just matching on title text.
class JobBrowseFilters {
  const JobBrowseFilters({this.search, this.location, this.employmentType});

  final String? search;
  final String? location;

  /// full_time | part_time | contract | internship — matches
  /// job.model.ts's IJob.employmentType exactly.
  final String? employmentType;

  JobBrowseFilters copyWith({
    String? search,
    bool clearSearch = false,
    String? location,
    bool clearLocation = false,
    String? employmentType,
    bool clearEmploymentType = false,
  }) =>
      JobBrowseFilters(
        search: clearSearch ? null : (search ?? this.search),
        location: clearLocation ? null : (location ?? this.location),
        employmentType: clearEmploymentType
            ? null
            : (employmentType ?? this.employmentType),
      );

  Map<String, dynamic> toQuery({required int page, int limit = 20}) => {
        'page': page,
        'limit': limit,
        if (search != null && search!.isNotEmpty) 'search': search,
        if (location != null && location!.isNotEmpty) 'location': location,
        if (employmentType != null) 'employmentType': employmentType,
      };
}

// ============================================================
// Shared: Job Detail (both recruiter and candidate views)
// ============================================================

/// Full job detail, shared by the recruiter's and candidate's Job Detail
/// screens (job_detail_screen.dart) — same GET /jobs/:jobId response,
/// same model; the screen itself decides what to show/allow based on role.
/// Carries fields JobListing (the browse-list card) doesn't need, like the
/// full description and raw requiredSkills/minYearsOfExperience/
/// educationLevel for the "Job Summary"/"Technical Requirements" sections.
class JobDetail {
  const JobDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.companyName,
    required this.location,
    required this.employmentType,
    required this.status,
    required this.requiredSkills,
    this.minYearsOfExperience,
    this.educationLevel,
    this.minSalary,
    this.maxSalary,
    this.currency,
  });

  final String id;
  final String title;
  final String description;
  final String companyName;
  final String location;
  final String? employmentType;
  final JobBackendStatus status;
  final List<String> requiredSkills;
  final int? minYearsOfExperience;
  final String? educationLevel;
  final double? minSalary;
  final double? maxSalary;
  final String? currency;

  static const _employmentTypeLabels = {
    'full_time': 'Full-time',
    'part_time': 'Part-time',
    'contract': 'Contract',
    'internship': 'Internship',
  };

  String get employmentTypeLabel =>
      _employmentTypeLabels[employmentType] ?? '—';

  static const _educationLabels = {
    'high_school': 'High School',
    'associate': 'Associate Degree',
    'bachelors': "Bachelor's Degree",
    'masters': "Master's Degree",
    'doctorate': 'Doctorate',
  };

  String? get educationLevelLabel => educationLevel == null
      ? null
      : (_educationLabels[educationLevel] ?? educationLevel);

  static const _currencySymbols = {
    'USD': '\$',
    'NGN': '₦',
    'EUR': '€',
    'GBP': '£'
  };

  /// Same formatting as JobListing.salaryRangeLabel — kept as a duplicate
  /// getter rather than a shared mixin since the two models otherwise have
  /// little in common; worth factoring out if a third place needs it.
  String? get salaryRangeLabel {
    if (minSalary == null && maxSalary == null) return null;
    final symbol = _currencySymbols[(currency ?? 'USD').toUpperCase()] ??
        '${currency ?? 'USD'} ';
    String fmt(double v) =>
        v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
    if (minSalary != null && maxSalary != null) {
      return '$symbol${fmt(minSalary!)} - $symbol${fmt(maxSalary!)} / year';
    }
    return '$symbol${fmt(minSalary ?? maxSalary!)}+ / year';
  }

  /// Maps GET /jobs/:jobId's raw job (job.service.ts's getJobById, now
  /// .populate('companyId')) into the shape this screen renders.
  factory JobDetail.fromApiJson(Map<String, dynamic> json) {
    final company = json['companyId'];
    final companyName = company is Map<String, dynamic>
        ? (company['name'] as String? ?? 'Unknown company')
        : 'Unknown company';

    return JobDetail(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      title: json['title'] as String? ?? 'Untitled role',
      description: json['description'] as String? ?? '',
      companyName: companyName,
      location: json['location'] as String? ?? 'Not specified',
      employmentType: json['employmentType'] as String?,
      status:
          JobBackendStatusJson.fromJson(json['status'] as String? ?? 'draft'),
      requiredSkills: (json['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      minYearsOfExperience: (json['minYearsOfExperience'] as num?)?.toInt(),
      educationLevel: json['educationLevel'] as String?,
      minSalary: (json['minSalary'] as num?)?.toDouble(),
      maxSalary: (json['maxSalary'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
    );
  }
}
