import 'package:dio/dio.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'models/activity_item.dart';
import 'models/recruiter_performance.dart';
import 'models/candidate_profile_model.dart';

/// Confirmed against candidateProfile.routes.ts: mounted with GET/PATCH
/// '/me', under a router whose swagger paths are '/api/candidate-profile/*'.
/// dio's baseUrl already includes '/api' (see dio_client.dart's
/// kApiBaseUrl), so the router's mount prefix here is '/candidate-profile'.
const String _profilePath = '/candidate-profile/me';

class CandidateProfileRepository {
  CandidateProfileRepository(this._dio);

  final Dio _dio;

  Future<CandidateProfile> getMyProfile() async {
    final response = await _dio.get(_profilePath);
    return CandidateProfile.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// `experience`/`education` replace wholesale, matching
  /// candidateProfile.service.ts's updateMyProfile semantics (`$set` on
  /// the whole array, not a diff) — always resend the complete local list,
  /// same as the manual-wizard flow already does.
  Future<CandidateProfile> updateProfile({
    List<ExperienceEntry>? experience,
    List<EducationEntry>? education,
  }) async {
    final response = await _dio.patch(_profilePath, data: {
      if (experience != null)
        'experience': experience.map((e) => e.toJson()).toList(),
      if (education != null)
        'education': education.map((e) => e.toJson()).toList(),
    });
    return CandidateProfile.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<UserModel> getMyAccount() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<RecruiterPerformance> getMyPerformance() async {
    final response = await _dio.get('/users/me/performance');
    return RecruiterPerformance.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// Cursor-paginated. Pass the previous page's `nextCursor` to load the
  /// next one — "View All History" on the profile screen just calls this
  /// again with the last cursor rather than a separate endpoint.
  Future<ActivityPage> getMyActivity({String? cursor, int limit = 10}) async {
    final response = await _dio.get('/users/me/activity', queryParameters: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });
    final items = (response.data['data'] as List<dynamic>)
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final nextCursor = (response.data['meta']
        as Map<String, dynamic>?)?['nextCursor'] as String?;
    return ActivityPage(items: items, nextCursor: nextCursor);
  }
}
