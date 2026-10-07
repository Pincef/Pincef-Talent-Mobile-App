/// lib/features/candidate_profile/data/models/candidate_profile_model.dart
library;

class ExperienceEntry {
  final String title;
  final String? company;
  final DateTime? startDate;
  final DateTime? endDate; // null = current role
  final String? description;
  final List<String> achievements;

  const ExperienceEntry({
    required this.title,
    this.company,
    this.startDate,
    this.endDate,
    this.description,
    this.achievements = const [],
  });

  bool get isCurrent => endDate == null;

  factory ExperienceEntry.fromJson(Map<String, dynamic> json) {
    return ExperienceEntry(
      title: json['title'] as String,
      company: json['company'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      description: json['description'] as String?,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (company != null) 'company': company,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (description != null) 'description': description,
      'achievements': achievements,
    };
  }
}

class EducationEntry {
  final String institution;
  final String? degree;
  final String? fieldOfStudy;
  final DateTime? startDate;
  final DateTime? endDate;

  const EducationEntry({
    required this.institution,
    this.degree,
    this.fieldOfStudy,
    this.startDate,
    this.endDate,
  });

  factory EducationEntry.fromJson(Map<String, dynamic> json) {
    return EducationEntry(
      institution: json['institution'] as String,
      degree: json['degree'] as String?,
      fieldOfStudy: json['fieldOfStudy'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'institution': institution,
      if (degree != null) 'degree': degree,
      if (fieldOfStudy != null) 'fieldOfStudy': fieldOfStudy,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
    };
  }
}

enum ProfileCertificationStatus { verified, verifying }

ProfileCertificationStatus _certStatusFromString(String value) {
  return value == 'verified'
      ? ProfileCertificationStatus.verified
      : ProfileCertificationStatus.verifying;
}

/// A candidate's uploaded certificate file — distinct from the recruiter
/// UserModel's Certification (name/issuer/dates); this one's an uploaded
/// document with a verification status, not a stated credential. Named
/// differently to avoid a symbol clash between the two features.
class ProfileCertification {
  final String name;
  final String url;
  final String? verifiedLabel;
  final ProfileCertificationStatus status;
  final DateTime uploadedAt;

  const ProfileCertification({
    required this.name,
    required this.url,
    this.verifiedLabel,
    required this.status,
    required this.uploadedAt,
  });

  factory ProfileCertification.fromJson(Map<String, dynamic> json) {
    return ProfileCertification(
      name: json['name'] as String,
      url: json['url'] as String,
      verifiedLabel: json['verifiedLabel'] as String?,
      status: _certStatusFromString(json['status'] as String),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }
}

/// Mirrors candidateProfile.model.ts's IPortfolioLink.
class PortfolioLink {
  const PortfolioLink(
      {required this.platform, required this.url, this.displayTitle});

  final String platform;
  final String url;
  final String? displayTitle;

  factory PortfolioLink.fromJson(Map<String, dynamic> json) {
    return PortfolioLink(
      platform: json['platform'] as String,
      url: json['url'] as String,
      displayTitle: json['displayTitle'] as String?,
    );
  }
}

/// Mirrors candidateProfile.model.ts's ICvFile.
class CvFile {
  const CvFile({
    required this.url,
    required this.publicId,
    required this.originalName,
    required this.size,
    required this.uploadedAt,
  });

  final String url;
  final String publicId;
  final String originalName;
  final int size; // bytes
  final DateTime uploadedAt;

  String get sizeLabel => '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';

  factory CvFile.fromJson(Map<String, dynamic> json) {
    return CvFile(
      url: json['url'] as String,
      publicId: json['publicId'] as String,
      originalName: json['originalName'] as String? ?? 'CV',
      size: (json['size'] as num?)?.toInt() ?? 0,
      uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Mirrors candidateProfile.model.ts's ILocation — a manual-wizard-only
/// field, so may be entirely absent on a CV-parsed profile.
class CandidateLocation {
  const CandidateLocation({this.city, this.stateName, this.countryName});

  final String? city;
  final String? stateName;
  final String? countryName;

  String get displayString => [city, stateName, countryName]
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .join(', ');

  factory CandidateLocation.fromJson(Map<String, dynamic> json) {
    return CandidateLocation(
      city: json['city'] as String?,
      stateName: json['stateName'] as String?,
      countryName: json['countryName'] as String?,
    );
  }
}

class CandidateProfile {
  final String?
      professionalTitle; // manual-wizard-only — often absent on a CV-parsed profile
  final String? bio; // same caveat as professionalTitle
  final CandidateLocation? location;
  final List<String> skills; // CV-parsed
  final List<ExperienceEntry> experience;
  final List<EducationEntry> education;
  final List<ProfileCertification> certifications;
  final List<PortfolioLink> portfolioLinks;
  final List<CvFile> cvFiles;

  /// AI-generated summary from CV parsing — falls back for [bio] on
  /// profiles created via CV upload rather than the manual wizard, since
  /// those never populate `bio`.
  final String? aiSummary;
  final DateTime profileUpdatedAt;

  const CandidateProfile({
    this.professionalTitle,
    this.bio,
    this.location,
    this.skills = const [],
    this.experience = const [],
    this.education = const [],
    this.certifications = const [],
    this.portfolioLinks = const [],
    this.cvFiles = const [],
    this.aiSummary,
    required this.profileUpdatedAt,
  });

  /// Prefers the manual-wizard bio, falls back to the CV-parser's
  /// aiSummary, and finally null if the candidate has neither yet.
  String? get displaySummary => (bio != null && bio!.isNotEmpty)
      ? bio
      : (aiSummary?.isNotEmpty == true ? aiSummary : null);

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    return CandidateProfile(
      professionalTitle: json['professionalTitle'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] != null
          ? CandidateLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      experience: (json['experience'] as List<dynamic>?)
              ?.map((e) => ExperienceEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => EducationEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) =>
                  ProfileCertification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      portfolioLinks: (json['portfolioLinks'] as List<dynamic>?)
              ?.map((e) => PortfolioLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cvFiles: (json['cvFiles'] as List<dynamic>?)
              ?.map((e) => CvFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      aiSummary: json['aiSummary'] as String?,
      profileUpdatedAt: DateTime.parse(json['profileUpdatedAt'] as String),
    );
  }
}
