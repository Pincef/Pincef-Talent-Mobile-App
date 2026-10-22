import 'package:dio/dio.dart';
import 'model/recruiter_dashboard_models.dart';

class RecruiterDashboardRepository {
  RecruiterDashboardRepository(this._dio);

  final Dio _dio;

  Future<RecruiterDashboardSummary> loadDashboard(
      {DateTime? from, DateTime? to}) async {
    final dateParams = <String, String>{};
    if (from != null) dateParams['from'] = from.toUtc().toIso8601String();
    if (to != null) {
      dateParams['to'] = DateTime(to.year, to.month, to.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();
    }
    final responses = await Future.wait([
      _dio.get('/dashboard/overview', queryParameters: dateParams),
      _dio.get('/dashboard/top-jobs',
          queryParameters: {'limit': 5, ...dateParams}),
      _dio.get('/jobs/mine'),
      _dio.get('/dashboard/applications-trend',
          queryParameters: {'months': 6, ...dateParams}),
    ]);
    Object? payloadOf(Response response) {
      final body = response.data;
      // Dashboard endpoints historically returned bare values. Accept both
      // forms so a backend deploy and an app update do not have to be atomic.
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    }

    Map<String, dynamic> dataOf(Response response) {
      final payload = payloadOf(response);
      if (payload is Map) return Map<String, dynamic>.from(payload);
      throw const FormatException(
          'Dashboard overview response was not an object');
    }

    List<Map<String, dynamic>> rowsOf(Response response) {
      final payload = payloadOf(response);
      if (payload is! List) return const [];
      return payload
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    final overview = dataOf(responses[0]);
    final topJobs = rowsOf(responses[1]);
    final allJobs = rowsOf(responses[2]);
    final trend = rowsOf(responses[3])
        .map((row) => ApplicationTrendPoint(
              year: (row['year'] as num?)?.toInt() ?? 0,
              month: (row['month'] as num?)?.toInt() ?? 0,
              count: (row['count'] as num?)?.toInt() ?? 0,
            ))
        .where((point) => point.month >= 1 && point.month <= 12)
        .toList();
    final jobsById = {
      for (final job in allJobs) (job['_id'] ?? job['id']).toString(): job
    };
    final rawStatuses = overview['applicationsByStatus'];
    final statuses = rawStatuses is Map
        ? Map<String, dynamic>.from(rawStatuses)
        : <String, dynamic>{};
    int count(String status) => (statuses[status] as num?)?.toInt() ?? 0;

    return RecruiterDashboardSummary(
      recruiterFirstName: '',
      activeJobs: (overview['activeJobs'] as num?)?.toInt() ?? 0,
      activeJobsNote:
          '${(overview['totalJobs'] as num?)?.toInt() ?? 0} total roles',
      newApplicants: count('submitted'),
      newApplicantsNote: 'Awaiting initial review',
      hiredThisMonth: count('hired'),
      hiredThisMonthNote: 'Marked hired during the selected dates',
      averageAiScore: (overview['averageAiScore'] as num?)?.toDouble(),
      totalApplications: (overview['totalApplications'] as num?)?.toInt() ?? 0,
      pipelineCounts: {
        for (final status in const [
          'submitted',
          'shortlisted',
          'interviewing',
          'offered',
          'hired',
          'rejected'
        ])
          status: count(status)
      },
      applicationTrend: trend,
      priorityJobs: topJobs.map((row) {
        final job = jobsById[(row['jobId'] ?? '').toString()] ?? const {};
        final status = job['status']?.toString() ?? '';
        return PriorityJob(
          id: (row['jobId'] ?? '').toString(),
          title: row['title'] as String? ?? 'Untitled role',
          department: [job['industry'], job['location']]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .join(' • '),
          applicantCount: (row['applicantCount'] as num?)?.toInt() ?? 0,
          status: status == 'published'
              ? JobPublishStatus.active
              : status == 'closed'
                  ? JobPublishStatus.closed
                  : JobPublishStatus.drafting,
        );
      }).toList(),
      recentActivity: const [],
    );
  }
}
