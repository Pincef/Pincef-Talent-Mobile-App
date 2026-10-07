import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_provider.dart' show dioProvider;
import '../data/models/profile_setup_models.dart';
import '../data/candidate_profile_setup_repository.dart';

final profileSetupRepositoryProvider = Provider<ProfileSetupRepository>((ref) {
  return ProfileSetupRepository(ref.watch(dioProvider));
});

class ProfileSetupState {
  const ProfileSetupState({
    this.step = 0,
    this.fullName = '',
    this.professionalTitle = '',
    this.phone = '',
    // Single free-text field per the single-page redesign — replaces the
    // Structured country/state/city/street fields, fetched from
    // locationsProvider (see the single-page screen's Location section)
    // — same backend-driven cascade the old 4-step wizard's Step 1 used.
    this.countryCode,
    this.countryName,
    this.stateCode,
    this.stateName,
    this.city,
    this.streetAddress = '',
    this.profileImageBytes,
    this.bio = '',
    // NEW — single-page redesign fields with no home in the old wizard.
    this.highestQualification,
    this.yearsOfExperience,
    this.skills = const [],
    this.cvBytes,
    this.cvFilename,
    this.personalWebsiteUrl = '',
    this.dribbbleBehanceUrl = '',
    this.agreedToTerms = false,
    this.workExperiences = const [],
    // The single-page redesign has no Education section at all, and
    // Professional Certificates starts empty rather than pre-seeded with
    // demo entries (those existed only to visually match the old 4-step
    // mock's Step 4 screenshot).
    this.educationHistory = const [],
    this.certifications = const [],
    this.portfolioLinks = const [],
    this.isSaving = false,
    this.saveError,
  });

  final int
      step; // 0-based; UI shows step + 1 — unused by the single-page screen, kept for now
  final String fullName;
  final String professionalTitle;
  final String phone;

  final String? countryCode;
  final String? countryName;
  final String? stateCode;
  final String? stateName;
  final String? city;
  final String streetAddress;

  final Uint8List? profileImageBytes;
  final String bio;
  final String? highestQualification;
  final int? yearsOfExperience;
  final List<String> skills;

  /// The picked CV/résumé's raw bytes, sent via a separate
  /// POST /candidate-profile/cv call at submit time — a different
  /// endpoint from everything else this screen collects. Null until a
  /// file is picked; optional per the screenshot (candidate can submit
  /// without one).
  final Uint8List? cvBytes;
  final String? cvFilename;

  /// Two dedicated fields per the new "Portfolio" card design (Personal
  /// Website URL + Dribbble/Behance Profile), replacing both the old
  /// multi-entry platform-dropdown modal and last round's single generic
  /// URL field. Each is synthesized into its own PortfolioLinkEntry on
  /// submit if non-empty — portfolioLinks itself stays in the state in
  /// case something else still adds entries via the old modal.
  final String personalWebsiteUrl;
  final String dribbbleBehanceUrl;

  /// No checkbox in the new design — kept for now in case a terms
  /// checkbox returns elsewhere, but completeProfile() no longer gates
  /// on it (see that method).
  final bool agreedToTerms;

  final List<WorkExperienceEntry> workExperiences;
  final List<EducationEntry> educationHistory;
  final List<CertificationEntry> certifications;
  final List<PortfolioLinkEntry> portfolioLinks;

  /// True only while the final completeProfile() call is in flight —
  /// nothing else in this wizard hits the network anymore, so there's
  /// no other source of "saving" to track.
  final bool isSaving;

  /// Set if the completeProfile() call fails. Cleared at the start of
  /// the next attempt.
  final String? saveError;

  /// First token of fullName, for the "Final step, Alex!" greeting on
  /// step 4. Falls back to 'there' rather than showing an empty greeting
  /// if the person skipped naming themselves in step 1.
  String get firstNameOrFallback {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// e.g. "Lagos, Lagos, Nigeria" — city/state/country joined, skipping
  /// whichever parts are still unset. Empty string if nothing's picked
  /// yet at all.
  String get locationDisplay {
    final parts = [city, stateName, countryName]
        .where((p) => p != null && p.trim().isNotEmpty);
    return parts.join(', ');
  }

  ProfileSetupState copyWith({
    int? step,
    String? fullName,
    String? professionalTitle,
    String? phone,
    String? countryCode,
    String? countryName,
    String? stateCode,
    String? stateName,
    String? city,
    String? streetAddress,
    Uint8List? profileImageBytes,
    // Needed because copyWith's usual `?? this.x` pattern can't tell "not
    // passed" apart from "explicitly clear this" when the new value is
    // null — set this true to actually clear the photo.
    bool clearProfileImage = false,
    String? bio,
    String? highestQualification,
    int? yearsOfExperience,
    List<String>? skills,
    Uint8List? cvBytes,
    String? cvFilename,
    bool clearCv = false,
    String? personalWebsiteUrl,
    String? dribbbleBehanceUrl,
    bool? agreedToTerms,
    List<WorkExperienceEntry>? workExperiences,
    List<EducationEntry>? educationHistory,
    List<CertificationEntry>? certifications,
    List<PortfolioLinkEntry>? portfolioLinks,
    bool? isSaving,
    String? saveError,
    bool clearSaveError = false,
  }) {
    return ProfileSetupState(
      step: step ?? this.step,
      fullName: fullName ?? this.fullName,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      stateCode: stateCode ?? this.stateCode,
      stateName: stateName ?? this.stateName,
      city: city ?? this.city,
      streetAddress: streetAddress ?? this.streetAddress,
      profileImageBytes: clearProfileImage
          ? null
          : (profileImageBytes ?? this.profileImageBytes),
      bio: bio ?? this.bio,
      highestQualification: highestQualification ?? this.highestQualification,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      skills: skills ?? this.skills,
      cvBytes: clearCv ? null : (cvBytes ?? this.cvBytes),
      cvFilename: clearCv ? null : (cvFilename ?? this.cvFilename),
      personalWebsiteUrl: personalWebsiteUrl ?? this.personalWebsiteUrl,
      dribbbleBehanceUrl: dribbbleBehanceUrl ?? this.dribbbleBehanceUrl,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      workExperiences: workExperiences ?? this.workExperiences,
      educationHistory: educationHistory ?? this.educationHistory,
      certifications: certifications ?? this.certifications,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      isSaving: isSaving ?? this.isSaving,
      saveError: clearSaveError ? null : (saveError ?? this.saveError),
    );
  }
}

class ProfileSetupNotifier extends StateNotifier<ProfileSetupState> {
  ProfileSetupNotifier(this._repository) : super(const ProfileSetupState());

  final ProfileSetupRepository _repository;
  static const totalSteps = 2;

  // --- Everything below is pure local state — nothing here touches the
  // network. Only completeProfile(), at the bottom, does. ---

  void updatePersonalInfo({
    required String fullName,
    required String professionalTitle,
  }) {
    state = state.copyWith(
        fullName: fullName, professionalTitle: professionalTitle);
  }

  void updateLocation({
    String? countryCode,
    String? countryName,
    String? stateCode,
    String? stateName,
    String? city,
    String? streetAddress,
  }) {
    state = state.copyWith(
      countryCode: countryCode,
      countryName: countryName,
      stateCode: stateCode,
      stateName: stateName,
      city: city,
      streetAddress: streetAddress,
    );
  }

  void updateBio(String bio) => state = state.copyWith(bio: bio);

  void updatePhone(String phone) => state = state.copyWith(phone: phone);

  void updateHighestQualification(String? value) =>
      state = state.copyWith(highestQualification: value);

  void updateYearsOfExperience(int? value) =>
      state = state.copyWith(yearsOfExperience: value);

  void addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty || state.skills.contains(trimmed)) return;
    state = state.copyWith(skills: [...state.skills, trimmed]);
  }

  void removeSkill(String skill) {
    state =
        state.copyWith(skills: state.skills.where((s) => s != skill).toList());
  }

  void setCv({required Uint8List bytes, required String filename}) {
    state = state.copyWith(cvBytes: bytes, cvFilename: filename);
  }

  void removeCv() => state = state.copyWith(clearCv: true);

  void setAgreedToTerms(bool value) =>
      state = state.copyWith(agreedToTerms: value);

  void updatePersonalWebsiteUrl(String url) =>
      state = state.copyWith(personalWebsiteUrl: url);

  void updateDribbbleBehanceUrl(String url) =>
      state = state.copyWith(dribbbleBehanceUrl: url);

  void updateProfileImage(Uint8List bytes) =>
      state = state.copyWith(profileImageBytes: bytes);

  void removeProfileImage() => state = state.copyWith(clearProfileImage: true);

  void addEducationEntry(EducationEntry entry) {
    state =
        state.copyWith(educationHistory: [entry, ...state.educationHistory]);
  }

  /// Real functionality now (the old wizard's Step 3 stubbed "Add
  /// Experience" to a snackbar) — the new Experience & Verification step
  /// needs this list to actually grow.
  void addWorkExperience(WorkExperienceEntry entry) {
    state = state.copyWith(workExperiences: [entry, ...state.workExperiences]);
  }

  void removeWorkExperience(int index) {
    final updated = [...state.workExperiences]..removeAt(index);
    state = state.copyWith(workExperiences: updated);
  }

  void removeEducationEntry(int index) {
    final updated = [...state.educationHistory]..removeAt(index);
    state = state.copyWith(educationHistory: updated);
  }

  void addPortfolioLink(PortfolioLinkEntry entry) {
    state = state.copyWith(portfolioLinks: [entry, ...state.portfolioLinks]);
  }

  void removePortfolioLink(int index) {
    final updated = [...state.portfolioLinks]..removeAt(index);
    state = state.copyWith(portfolioLinks: updated);
  }

  /// Called from Step 4's certificate dropzone once a PDF is picked —
  /// keeps the file's bytes in memory (see CertificationEntry.fileBytes)
  /// so it can go out with everything else at completeProfile() time.
  void addCertification({required Uint8List bytes, required String filename}) {
    final entry = CertificationEntry(
      name: filename,
      status: CertificationStatus.verifying,
      fileBytes: bytes,
    );
    state = state.copyWith(certifications: [entry, ...state.certifications]);
  }

  void removeCertification(int index) {
    final updated = [...state.certifications]..removeAt(index);
    state = state.copyWith(certifications: updated);
  }

  // --- The one method that actually talks to the network. ---

  /// The single "JOIN TALENT POOL" button awaits this. Three separate
  /// backend calls, because the fields on this one page genuinely belong
  /// to three different endpoints:
  ///   1. POST /candidate-profile/manual — everything CandidateProfile owns
  ///   2. PATCH /users/me — phone (a User field, not CandidateProfile) —
  ///      only fires if state.phone is ever set; the new 2-step design has
  ///      no phone field, so this is effectively a no-op for now
  ///   3. POST /candidate-profile/cv — the résumé, if one was picked —
  ///      same story: no CV field in the new design, so this won't fire
  ///      unless something else in the app sets state.cvBytes
  /// All three run before reporting success, so a partial failure doesn't
  /// silently drop data — see saveError for which part failed.
  Future<bool> completeProfile() async {
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final portfolioLinks = [
        ...state.portfolioLinks,
        if (state.personalWebsiteUrl.trim().isNotEmpty)
          PortfolioLinkEntry(
            platform: 'Personal Website',
            url: state.personalWebsiteUrl.trim(),
            displayTitle: '',
          ),
        if (state.dribbbleBehanceUrl.trim().isNotEmpty)
          PortfolioLinkEntry(
            platform: 'Dribbble/Behance',
            url: state.dribbbleBehanceUrl.trim(),
            displayTitle: '',
          ),
      ];

      await _repository.completeProfile(
        fullName: state.fullName,
        professionalTitle: state.professionalTitle,
        bio: state.bio,
        countryCode: state.countryCode,
        countryName: state.countryName,
        stateCode: state.stateCode,
        stateName: state.stateName,
        city: state.city,
        streetAddress: state.streetAddress,
        highestQualification: state.highestQualification,
        skills: state.skills,
        workExperiences: state.workExperiences,
        education: state.educationHistory,
        portfolioLinks: portfolioLinks,
        certifications: state.certifications,
        profilePhotoBytes: state.profileImageBytes,
      );

      if (state.phone.trim().isNotEmpty) {
        await _repository.updatePhone(state.phone.trim());
      }

      if (state.cvBytes != null) {
        await _repository.uploadCv(
          bytes: state.cvBytes!,
          filename: state.cvFilename ?? 'resume.pdf',
        );
      }

      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: e.toString());
      return false;
    }
  }

  void next() {
    if (state.step < totalSteps - 1) {
      state = state.copyWith(step: state.step + 1);
    }
  }

  void back() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1);
    }
  }
}

final profileSetupProvider =
    StateNotifierProvider<ProfileSetupNotifier, ProfileSetupState>((ref) {
  return ProfileSetupNotifier(ref.watch(profileSetupRepositoryProvider));
});
