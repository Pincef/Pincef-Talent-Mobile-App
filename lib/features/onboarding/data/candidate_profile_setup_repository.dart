import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import 'models/profile_setup_models.dart';

/// Talks to the candidate profile-setup backend (`POST
/// /candidate-profile/manual`).
///
/// FIX: this used to send a JSON body and explicitly drop the profile photo
/// and certificate files, because the backend route had no multer
/// middleware to receive them. The route is now multipart-capable (see
/// candidateProfile.routes.ts), so this sends a real multipart/form-data
/// request instead: plain fields as form fields, `education` and
/// `portfolioLinks` as JSON-encoded strings (multipart has no native
/// array/object type), and the photo/certificate files as actual file
/// parts. Field names match the backend's `manualProfileCreationSchema`
/// (see candidate.dto.ts) exactly, so nothing here should be renamed
/// without updating that schema too.
class ProfileSetupRepository {
  ProfileSetupRepository(this._dio);
  final Dio _dio;

  Future<void> completeProfile({
    required String fullName,
    required String professionalTitle,
    required String bio,
    String? countryCode,
    String? countryName,
    String? stateCode,
    String? stateName,
    String? city,
    required String streetAddress,
    String? highestQualification,
    List<String> skills = const [],
    required List<EducationEntry> education,
    List<WorkExperienceEntry> workExperiences = const [],
    required List<PortfolioLinkEntry> portfolioLinks,
    required List<CertificationEntry> certifications,
    Uint8List? profilePhotoBytes,
    String profilePhotoFilename = 'profile.jpg',
  }) async {
    try {
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('fullName', fullName),
        MapEntry('professionalTitle', professionalTitle),
        MapEntry('bio', bio),
        if (countryCode != null) MapEntry('countryCode', countryCode),
        if (countryName != null) MapEntry('countryName', countryName),
        if (stateCode != null) MapEntry('stateCode', stateCode),
        if (stateName != null) MapEntry('stateName', stateName),
        if (city != null) MapEntry('city', city),
        MapEntry('streetAddress', streetAddress),
        // NEW — candidateProfile.model.ts now has `highestQualification`,
        // but I don't have candidate.dto.ts's manualProfileCreationSchema
        // to confirm it (or `skills`) actually validate/persist yet on
        // the backend — see the note left alongside this batch of changes.
        if (highestQualification != null)
          MapEntry('highestQualification', highestQualification),
        MapEntry('skills', jsonEncode(skills)),
        // NEW — the old manual-profile endpoint never accepted work
        // experience at all (only CV-parsing wrote to it). Same
        // unconfirmed-schema situation as skills/highestQualification
        // above: sent here, but candidate.dto.ts's
        // manualProfileCreationSchema needs to actually accept+persist it.
        MapEntry(
          'experience',
          jsonEncode(
            workExperiences
                .map((e) => {
                      'title': e.title,
                      'company': e.company,
                      'employmentType': e.employmentType,
                      'startYear': e.startYear,
                      'endYear': e.endYear,
                    })
                .toList(),
          ),
        ),
        MapEntry(
          'education',
          jsonEncode(
            education
                .map((e) => {
                      'school': e.school,
                      'programme': e.programme,
                      'startYear': e.startYear,
                      'endYear': e.endYear,
                    })
                .toList(),
          ),
        ),
        MapEntry(
          'portfolioLinks',
          jsonEncode(
            portfolioLinks
                .map((p) => {
                      'platform': p.platform,
                      'url': p.url,
                      'displayTitle': p.displayTitle,
                    })
                .toList(),
          ),
        ),
      ]);

      // FIX: previously never attached — see class doc comment above.
      if (profilePhotoBytes != null) {
        formData.files.add(
          MapEntry(
            'profilePhoto',
            MultipartFile.fromBytes(profilePhotoBytes,
                filename: profilePhotoFilename),
          ),
        );
      }

      // FIX: certifications were never sent at all before. Only entries
      // with real picked bytes go out — the two seeded demo entries (see
      // ProfileSetupState's initial certifications list) were never a real
      // upload, so there's nothing to attach for them. Repeated
      // MapEntry('certificates', ...) entries are exactly what
      // multer's `.fields([{ name: 'certificates', maxCount: ... }])`
      // expects on the other end.
      for (final cert in certifications) {
        final bytes = cert.fileBytes;
        if (bytes == null) continue;
        formData.files.add(
          MapEntry(
            'certificates',
            MultipartFile.fromBytes(bytes, filename: cert.name),
          ),
        );
      }

      await _dio.post('/candidate-profile/manual', data: formData);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Phone lives on User, not CandidateProfile — updateMyAccountSchema
  /// (user.dto.ts) already accepts it, same field the Settings screens use.
  Future<void> updatePhone(String phone) async {
    try {
      await _dio.patch('/users/me', data: {'phone': phone});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// A genuinely different endpoint from completeProfile() above — CV
  /// upload/parsing is its own flow (candidateProfile.routes.ts's POST
  /// /cv, field name 'cv', PDF only — see the note on why DOCX isn't
  /// accepted despite the screenshot's copy). Optional: the single-page
  /// screen only calls this when a file was actually picked.
  Future<void> uploadCv(
      {required Uint8List bytes, required String filename}) async {
    try {
      final formData = FormData.fromMap({
        'cv': MultipartFile.fromBytes(bytes, filename: filename),
      });
      await _dio.post('/candidate-profile/cv', data: formData);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
