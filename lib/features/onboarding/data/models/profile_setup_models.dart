import 'dart:typed_data';

/// Simple data holders for the candidate profile-setup wizard. All of
/// this stays local until Step 4's "Complete Profile" — see
/// candidate_profile_setup_repository.dart's completeProfile(), the only
/// method in the wizard that talks to the network.

class WorkExperienceEntry {
  const WorkExperienceEntry({
    required this.title,
    required this.company,
    required this.employmentType,
    required this.startYear,
    this.endYear, // null means "Present"
  });

  final String title;
  final String company;

  /// e.g. "Full-time", "Contract" — shown on the card per the new
  /// Experience & Verification step design.
  final String employmentType;
  final String startYear;
  final String? endYear;
}

class EducationEntry {
  const EducationEntry({
    required this.school,
    required this.programme,
    required this.startYear,
    this.endYear, // null means "Present" (still studying)
  });

  final String school;
  final String programme;
  final String startYear;
  final String? endYear;
}

enum CertificationStatus { verified, verifying }

class CertificationEntry {
  const CertificationEntry({
    required this.name,
    required this.status,
    this.verifiedLabel,
    this.fileBytes,
  });

  final String name;
  final CertificationStatus status;

  /// e.g. "Verified Dec 2023" — only meaningful when status is verified.
  final String? verifiedLabel;

  /// The picked PDF's raw bytes — kept in memory so the file can be sent
  /// along with everything else at final submit, rather than uploaded
  /// the moment it's picked. Null for the two seeded demo entries (they
  /// were never a real upload, so there's nothing to submit for them).
  final Uint8List? fileBytes;
}

class PortfolioLinkEntry {
  const PortfolioLinkEntry({
    required this.platform,
    required this.url,
    required this.displayTitle,
  });

  final String platform;
  final String url;
  final String displayTitle;
}
