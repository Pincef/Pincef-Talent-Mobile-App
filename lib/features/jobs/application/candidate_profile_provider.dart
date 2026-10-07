/// lib/features/jobs/application/candidate_profile_view_provider.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import '../data/models/candidate_profile_model.dart';
import '../data/candidate_profile_repository.dart';
import '../data/models/candidate_analysis_model.dart';

final candidateProfileViewRepositoryProvider =
    Provider<CandidateProfileViewRepository>((ref) {
  return CandidateProfileViewRepository(ref.watch(dioProvider));
});

/// Everything CandidateProfilePreviewScreen needs, bundled into one load so
/// the screen has a single loading/error state instead of juggling three.
class CandidateProfileViewData {
  const CandidateProfileViewData({
    required this.profile,
    required this.user,
    required this.analysis,
  });

  final CandidateProfile profile;
  final UserModel user;

  /// Null only if analysis fetch/request itself failed outright (network
  /// error etc.) — a resolved-but-FAILED analysis still comes through as a
  /// non-null CandidateJobAnalysis with status.failed, which the UI should
  /// show as "couldn't be scored" rather than hiding the card entirely.
  final CandidateJobAnalysis? analysis;
}

final candidateProfileViewProvider = FutureProvider.autoDispose
    .family<CandidateProfileViewData, ({String candidateId, String jobId})>(
        (ref, args) async {
  final repo = ref.watch(candidateProfileViewRepositoryProvider);

  final results = await Future.wait([
    repo.getCandidateProfile(args.candidateId),
    repo.getCandidateUser(args.candidateId),
  ]);
  final profile = results[0] as CandidateProfile;
  final user = results[1] as UserModel;

  CandidateJobAnalysis? analysis;
  try {
    analysis = await repo.getJobAnalysis(args.candidateId, args.jobId);
    analysis ??= await repo.requestJobAnalysis(args.candidateId, args.jobId);
  } catch (_) {
    analysis = null;
  }

  return CandidateProfileViewData(
      profile: profile, user: user, analysis: analysis);
});
