import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../data/model/recruitment_report_model.dart';
import '../data/recruitment_report_repository.dart';

final recruitmentReportRepositoryProvider =
    Provider((ref) => RecruitmentReportRepository(ref.watch(dioProvider)));
final recruitmentReportProvider = FutureProvider<RecruitmentReport>(
    (ref) => ref.watch(recruitmentReportRepositoryProvider).loadReport());
