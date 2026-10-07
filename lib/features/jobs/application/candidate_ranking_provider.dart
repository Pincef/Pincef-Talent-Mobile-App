import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/models/candidate_ranking_model.dart';
import '../data/candidate_ranking_repository.dart';

final candidateRankingRepositoryProvider = Provider<CandidateRankingRepository>(
  (ref) => CandidateRankingRepository(ref.watch(dioProvider)),
);

/// autoDispose: this is an expensive, non-cached AI computation — don't
/// keep it warm in memory once the recruiter navigates away, and re-run it
/// fresh the next time they open this screen (matching the "never
/// persisted, always current" behavior on the backend side).
final candidateRankingProvider = FutureProvider.autoDispose
    .family<CandidateRankingResult, String>((ref, jobId) {
  return ref.watch(candidateRankingRepositoryProvider).rankAllCandidates(jobId);
});
