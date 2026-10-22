import 'package:dio/dio.dart';
import 'model/recruitment_report_model.dart';

class RecruitmentReportRepository {
  RecruitmentReportRepository(this._dio);
  final Dio _dio;

  Future<RecruitmentReport> loadReport() async {
    final response = await _dio.get('/dashboard/overview');
    final body = response.data;
    final raw = body is Map && body['data'] is Map ? body['data'] as Map : body;
    if (raw is! Map)
      throw const FormatException('Recruiter report data is unavailable.');
    final overview = Map<String, dynamic>.from(raw);
    final rawStatuses = overview['applicationsByStatus'];
    final statuses = rawStatuses is Map
        ? Map<String, dynamic>.from(rawStatuses)
        : <String, dynamic>{};
    int count(String key) => (statuses[key] as num?)?.toInt() ?? 0;
    final total = (overview['totalApplications'] as num?)?.toInt() ??
        statuses.values
            .whereType<num>()
            .fold<int>(0, (sum, value) => sum + value.toInt());
    final stageCounts = <String, int>{
      'Applications': total,
      'Shortlisted': count('shortlisted'),
      'Interviewing': count('interviewing'),
      'Offers': count('offered'),
      'Hires': count('hired'),
    };
    return RecruitmentReport(
      totalApplicants: total,
      avgDaysToFill: (overview['avgDaysToFill'] as num?)?.toInt() ?? 0,
      pipelineHealth: (overview['pipelineHealth'] as num?)?.toDouble() ?? 0,
      totalHires: count('hired'),
      sources: const [],
      stages: [
        for (final entry in stageCounts.entries)
          FunnelStage(entry.key, 0, 0, entry.value),
      ],
      dropOffReasons: const [],
    );
  }
}
