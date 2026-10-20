import 'package:dio/dio.dart';
import '../../../core/network/dio_provider.dart';
import 'model/recruiter_dashboard_models.dart';

class RecruiterDashboardRepository {
  RecruiterDashboardRepository(this._dio);

  final Dio _dio;

  Future<RecruiterDashboardSummary> loadDashboard() async {
    final responses = await Future.wait([
      _dio.get('/dashboard/overview'),
      _dio.get('/dashboard/top-jobs', queryParameters: {'limit': 5}),
      _dio.get('/jobs/mine'),
      _dio.get('/dashboard/applications-trend', queryParameters: {'months': 6}),
    ]);
    Map<String, dynamic> dataOf(Response response) =>
        Map<String, dynamic>.from(response.data['data'] as Map);
    final overview = dataOf(responses[0]);
    final topJobs = (responses[1].data['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final allJobs = (responses[2].data['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final trend = (responses[3].data['data'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => ApplicationTrendPoint(
              year: (row['year'] as num?)?.toInt() ?? 0,
              month: (row['month'] as num?)?.toInt() ?? 0,
              count: (row['count'] as num?)?.toInt() ?? 0,
            ))
        .toList();
    final jobsById = {
      for (final job in allJobs) (job['_id'] ?? job['id']).toString(): job
    };
    final statuses = Map<String, dynamic>.from(
        overview['applicationsByStatus'] as Map? ?? const {});
    int count(String status) => (statuses[status] as num?)?.toInt() ?? 0;

    return RecruiterDashboardSummary(
      recruiterFirstName: '',
      activeJobs: (overview['activeJobs'] as num?)?.toInt() ?? 0,
      activeJobsNote:
          '${(overview['totalJobs'] as num?)?.toInt() ?? 0} total roles',
      newApplicants: count('submitted'),
      newApplicantsNote: 'Awaiting initial review',
      hiredThisMonth: count('hired'),
      hiredThisMonthNote: 'Applications in hired stage',
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
