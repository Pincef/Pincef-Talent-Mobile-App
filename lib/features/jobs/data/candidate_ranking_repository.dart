import 'package:dio/dio.dart';
import '../../../core/network/api_exception.dart';
import './models/candidate_ranking_model.dart';

/// Ranking is computed fresh on every call, never cached/persisted server-
/// side — new applicants can show up at any moment, so a stored ranking
/// would be stale the instant it's saved. That's why this is a POST rather
/// than a GET: it's "compute this now," not "fetch the stored thing."
///
/// PLACEHOLDER: the actual backend endpoint for this doesn't exist yet —
/// this path/response-shape is a best guess to unblock the UI. Update
/// [_endpointFor] and [CandidateRankingResult.fromApiJson] once the real
/// contract is shared; nothing else in this file should need to change.
class CandidateRankingRepository {
  CandidateRankingRepository(this._dio);

  final Dio _dio;

  String _endpointFor(String jobId) => '/jobs/$jobId/candidate-ranking';

  Future<CandidateRankingResult> rankAllCandidates(String jobId) async {
    try {
      final res = await _dio.post(_endpointFor(jobId));
      final body = res.data;
      if (body == null) return const CandidateRankingResult.empty();
      final data = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
      return CandidateRankingResult.fromApiJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
