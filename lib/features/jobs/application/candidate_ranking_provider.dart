import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/models/candidate_ranking_model.dart';
import '../data/candidate_ranking_repository.dart';

final candidateRankingRepositoryProvider = Provider<CandidateRankingRepository>(
  (ref) => CandidateRankingRepository(ref.watch(dioProvider)),
);

/// Discard the read when the recruiter leaves the screen. The backend keeps
/// completed deadline-run results and serves the current persisted ranking.
final candidateRankingProvider = FutureProvider.autoDispose
    .family<CandidateRankingResult, String>((ref, jobId) {
  return ref.watch(candidateRankingRepositoryProvider).loadJobRankings(jobId);
});
