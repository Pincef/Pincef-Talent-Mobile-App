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

class CandidateProfile {
  final List<ExperienceEntry> experience;
  final List<EducationEntry> education;
  final List<ProfileCertification> certifications;
  final DateTime profileUpdatedAt;

  const CandidateProfile({
    this.experience = const [],
    this.education = const [],
    this.certifications = const [],
    required this.profileUpdatedAt,
  });

  factory CandidateProfile.fromJson(Map<String, dynamic> json) {
    return CandidateProfile(
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
      profileUpdatedAt: DateTime.parse(json['profileUpdatedAt'] as String),
    );
  }
}
