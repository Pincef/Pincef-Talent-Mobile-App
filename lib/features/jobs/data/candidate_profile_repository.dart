/// lib/features/jobs/data/candidate_profile_view_repository.dart
library;

import 'package:dio/dio.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import './models/candidate_profile_model.dart';
import 'models/candidate_analysis_model.dart';

/// Recruiter-facing reads only — this is a *different* candidate's profile,
/// never the signed-in user's own (that's CandidateProfileRepository in the
/// candidate_profile feature). Kept separate rather than reused since the
/// access pattern and permissions are genuinely different (recruiter
/// viewing an applicant vs a candidate viewing themselves), even though
/// both parse the same CandidateProfile/UserModel shapes.
class CandidateProfileViewRepository {
  CandidateProfileViewRepository(this._dio);

  final Dio _dio;

  /// Maps to: GET /candidate-profile/:candidateId -> getProfileByCandidateId.
  Future<CandidateProfile> getCandidateProfile(String candidateId) async {
    final response = await _dio.get('/candidate-profile/$candidateId');
    return CandidateProfile.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// Maps to: GET /users/:userId -> userController.getUserById. Reuses
  /// UserModel since the fields needed here (name/email/phone/photo) are
  /// exactly what that model already parses.
  Future<UserModel> getCandidateUser(String candidateId) async {
    final response = await _dio.get('/users/$candidateId');
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Maps to: GET /candidate-profile/:candidateId/jobs/:jobId/analysis ->
  /// getJobAnalysis. Returns null on a 404 (no analysis requested yet)
  /// rather than throwing, so the caller can fall back to
  /// [requestJobAnalysis] without special-casing the error.
  Future<CandidateJobAnalysis?> getJobAnalysis(
      String candidateId, String jobId) async {
    try {
      final response = await _dio
          .get('/candidate-profile/$candidateId/jobs/$jobId/analysis');
      return CandidateJobAnalysis.fromJson(
          response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Maps to: POST /candidate-profile/:candidateId/jobs/:jobId/analyze ->
  /// requestJobAnalysis. Per candidateProfile.controller.ts's comment,
  /// matching now runs inline, so this resolves to COMPLETED/FAILED
  /// synchronously rather than needing to be polled.
  Future<CandidateJobAnalysis> requestJobAnalysis(
      String candidateId, String jobId) async {
    final response =
        await _dio.post('/candidate-profile/$candidateId/jobs/$jobId/analyze');
    return CandidateJobAnalysis.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}
