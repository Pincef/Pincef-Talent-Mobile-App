import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/model/recruitment_report_model.dart';
import '../data/recruitment_report_repository.dart';

final recruitmentReportRepositoryProvider = Provider((ref) => RecruitmentReportRepository());
final recruitmentReportProvider = FutureProvider<RecruitmentReport>((ref) => ref.watch(recruitmentReportRepositoryProvider).loadReport());
