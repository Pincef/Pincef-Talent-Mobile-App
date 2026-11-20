import 'package:dio/dio.dart';
import 'model/recruitment_report_model.dart';

class RecruitmentReportRepository {
  RecruitmentReportRepository(this._dio);
  final Dio _dio;

  Future<RecruitmentReport> loadReport() async {
    final responses = await Future.wait([
      _dio.get('/dashboard/overview'),
      _dio.get('/dashboard/applications-trend',
          queryParameters: const {'months': 6}),
    ]);

    Object? payloadOf(Response response) {
      final body = response.data;
      return body is Map && body.containsKey('data') ? body['data'] : body;
    }

    final raw = payloadOf(responses[0]);
    if (raw is! Map) {
      throw const FormatException('Recruiter report data is unavailable.');
    }
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
    final rawTrend = payloadOf(responses[1]);
    final trend = rawTrend is List
        ? rawTrend
            .whereType<Map>()
            .map((row) => ApplicationTrendPoint(
                  year: (row['year'] as num?)?.toInt() ?? 0,
                  month: (row['month'] as num?)?.toInt() ?? 0,
                  count: (row['count'] as num?)?.toInt() ?? 0,
                ))
            .where((point) => point.year > 0 && point.month >= 1 && point.month <= 12)
            .toList()
        : <ApplicationTrendPoint>[];
    return RecruitmentReport(
      totalApplicants: total,
      shortlisted: count('shortlisted'),
      rejected: count('rejected'),
      totalHires: count('hired'),
      activeJobs: (overview['activeJobs'] as num?)?.toInt() ?? 0,
      applicationTrend: trend,
      sources: const [],
      stages: [
        FunnelStage('New applications', count('submitted')),
        FunnelStage('Shortlisted', count('shortlisted')),
        FunnelStage('Interviewing', count('interviewing')),
        FunnelStage('Offers', count('offered')),
        FunnelStage('Hired', count('hired')),
        FunnelStage('Rejected', count('rejected')),
      ],
      dropOffReasons: const [],
    );
  }
}
