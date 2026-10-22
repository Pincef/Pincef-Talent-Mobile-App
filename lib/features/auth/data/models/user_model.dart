enum UserRole { candidate, recruiter, admin }

/// Temporary global plan-gate bypass for product testing.
const bool billingGuardsEnabled = false;

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'recruiter':
      return UserRole.recruiter;
    case 'admin':
      return UserRole.admin;
    case 'candidate':
    default:
      return UserRole.candidate;
  }
}

class ProfileImage {
  final String url;
  final String publicId;

  const ProfileImage({required this.url, required this.publicId});

  factory ProfileImage.fromJson(Map<String, dynamic> json) {
    return ProfileImage(
      url: json['url'] as String,
      publicId: json['publicId'] as String,
    );
  }
}

class Certification {
  final String name;
  final String? issuer;
  final DateTime? issuedAt;
  final DateTime? validThru;

  const Certification({
    required this.name,
    this.issuer,
    this.issuedAt,
    this.validThru,
  });

  factory Certification.fromJson(Map<String, dynamic> json) {
    return Certification(
      name: json['name'] as String,
      issuer: json['issuer'] as String?,
      issuedAt: json['issuedAt'] != null
          ? DateTime.parse(json['issuedAt'] as String)
          : null,
      validThru: json['validThru'] != null
          ? DateTime.parse(json['validThru'] as String)
          : null,
    );
  }
}

class WorkPreferences {
  final bool remoteFriendly;
  final bool activeSeeking;

  const WorkPreferences({
    this.remoteFriendly = false,
    this.activeSeeking = false,
  });

  factory WorkPreferences.fromJson(Map<String, dynamic> json) {
    return WorkPreferences(
      remoteFriendly: json['remoteFriendly'] as bool? ?? false,
      activeSeeking: json['activeSeeking'] as bool? ?? false,
    );
  }
}

class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? companyId; // set once a recruiter has created/joined a Company
  final bool isVerified;
  final String? accessToken;

  /// Plan/add-on entitlements supplied by the backend. An empty list is
  /// meaningful (the user has no optional modules); null means an older
  /// response omitted the field.
  final List<String>? modules;
  final Map<String, dynamic> capabilities;
  /// Subscription quotas returned by the backend (for example
  /// `jobsPerMonth`). The server remains authoritative for enforcement.
  final Map<String, dynamic> limits;

  // NEW — profile screen fields. All optional/defaulted since older
  // accounts (and candidates, for now) won't have them set yet.
  final ProfileImage? profileImage;
  final String? bio;
  final String? location;
  final String? country;
  final List<String> competencies;
  final List<Certification> certifications;

  // NEW — candidate Settings > Profile Information.
  final String? phone;
  final WorkPreferences workPreferences;

  const UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.companyId,
    required this.isVerified,
    this.accessToken,
    this.modules,
    this.capabilities = const {},
    this.limits = const {},
    this.profileImage,
    this.bio,
    this.location,
    this.country,
    this.competencies = const [],
    this.certifications = const [],
    this.phone,
    this.workPreferences = const WorkPreferences(),
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawCapabilities = json['capabilities'];
    final rawLimits = json['limits'];
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String,
      role: userRoleFromString(json['role'] as String),
      companyId: json['companyId'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      modules: !billingGuardsEnabled ? const ['job.pipeline','jobs.unlimited_post','jobs.boost','analytics.advanced','analytics.basic','ai.candidate_match','ai.candidate_summary','ai.candidate_interview','ai.candidate_engagement','ai.candidate_outreach','ai.candidate_outreach_templates','ai.candidate_outreach_scheduling','ai.candidate_outreach_analytics','ai.candidate_outreach_personalization','ai.candidate_outreach_a_b_testing','ai.candidate_outreach_multi_channel','ai.candidate_outreach_integrations','ai.candidate_outreach_automation','ai.candidate_outreach_customization','ai.candidate_outreach_reporting','ai.candidate_outreach_security','team.extra_seats','hiring.pipeline','ai.cv_parsing','hiring.stage.interview','hiring.stage.assessment','hiring.candidate.messaging'] : json['modules'] is List
          ? (json['modules'] as List).map((e) => e.toString()).toList()
          : null,
      capabilities: !billingGuardsEnabled ? const {'allowsPlanAutomation':true,'allowsCandidateMessaging':true,'allowsCustomPipelines':true,'allowsPremiumPipeline':true,'allowsAiJobDescriptionGeneration':true,'maxCustomPipelines':999999} : rawCapabilities is Map
          ? Map<String, dynamic>.from(rawCapabilities)
          : const {},
      limits: !billingGuardsEnabled ? const {'jobsPerMonth':-1,'pipelines':-1,'cvUploads':-1,'rankingsPerJob':-1,'assessmentEmailsPerJob':-1,'interviewInvitesPerJob':-1} : rawLimits is Map ? Map<String, dynamic>.from(rawLimits) : const {},
      profileImage: json['profileImage'] != null
          ? ProfileImage.fromJson(json['profileImage'] as Map<String, dynamic>)
          : null,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      country: json['country'] as String?,
      competencies: (json['competencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => Certification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      phone: json['phone'] as String?,
      workPreferences: json['workPreferences'] != null
          ? WorkPreferences.fromJson(
              json['workPreferences'] as Map<String, dynamic>)
          : const WorkPreferences(),
    );
  }

  bool hasModule(String code) => !billingGuardsEnabled || (modules?.contains(code) ?? false);

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isEmpty ? email : combined;
  }

  /// Recruiter has signed up but hasn't completed the "create company" step yet.
  bool get needsCompanySetup => role == UserRole.recruiter && companyId == null;
}
