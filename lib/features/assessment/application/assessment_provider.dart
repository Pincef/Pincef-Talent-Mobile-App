import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/assessment_repository.dart';

final assessmentRepositoryProvider =
    Provider((ref) => AssessmentRepository(ref.watch(dioProvider)));

final recruiterAssessmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) =>
        ref.watch(assessmentRepositoryProvider).listRecruiterAssessments());

final candidateAssessmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.watch(assessmentRepositoryProvider).listMine());
