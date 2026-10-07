import 'package:dio/dio.dart';
import 'models/job_management_model.dart';

/// Real HTTP implementation, replacing the previous stub-with-dummy-data
/// version. Method signatures still mirror job.service.ts:
///   createJob(recruiterId, companyId, input, publishImmediately)
///   updateJob(jobId, companyId, input)
///   publishJob(jobId, companyId)
///   updateJobStatus(jobId, companyId, status)
///   listJobsByCompany(companyId)
/// recruiterId/companyId are never passed from here — they're derived
/// server-side from the auth token DioClient attaches to every request.
class JobManagementRepository {
  JobManagementRepository(this._dio);

  final Dio _dio;

  /// Maps to: GET /jobs/mine -> listJobsByCompany(companyId).
  ///
  /// There's no server-side status/pagination filtering on this route yet
  /// (only the public GET / route accepts page/limit/search/location), so
  /// this fetches the full list and filters/aggregates client-side via
  /// [JobManagementSummary.fromJobs]. [tab] controls which status is shown
  /// in `postings` — pass it again on tab change.
  Future<JobManagementSummary> loadJobManagement({
    JobPipelineStatus tab = JobPipelineStatus.active,
  }) {
    return _request(
      () => _dio.get('/jobs/mine'),
      (data) {
        final jobs = (data as List).cast<Map<String, dynamic>>();
        final postings = jobs.map(JobPosting.fromApiJson).toList();
        return JobManagementSummary.fromJobs(postings, tab);
      },
    );
  }

  /// Creates the job as a DRAFT and returns its id — every later save (and
  /// publish) needs this id to target the same record instead of creating
  /// duplicates.
  ///
  /// Maps to: POST /jobs -> createJob(recruiterId, companyId, input).
  /// The backend requires title + description together on create
  /// (job.dto.ts's createJobSchema) — the single-screen form already
  /// builds the full JobDraft before calling this, so both are always
  /// present by the time this fires.
  Future<String> createJobDraft(JobDraft draft) {
    return _request(
      () => _dio.post('/jobs', data: draft.toJson()),
      (data) => (data['_id'] ?? data['id']) as String,
    );
  }

  /// Merges [draft]'s fields into the existing job.
  ///
  /// Maps to: PATCH /jobs/:jobId -> updateJob(jobId, companyId, input).
  Future<void> updateJobDraft(String jobId, JobDraft draft) {
    return _request(
      () => _dio.patch('/jobs/$jobId', data: draft.toJson()),
      (_) {},
    );
  }

  /// Maps to: POST /jobs/:jobId/publish -> publishJob(jobId, companyId).
  ///
  /// Requires the publish route added to job.route.ts/job.controller.ts —
  /// don't swap this for PATCH /jobs/:jobId/status with status:
  /// 'published'. That hits updateJobStatus on the backend, which skips
  /// the REQUIRED_FOR_PUBLISH completeness check entirely, so an
  /// incomplete job could go live silently.
  ///
  /// Throws with the backend's "Cannot publish job — missing: ..."
  /// message on failure — surface it as-is, it names exactly which
  /// fields are missing.
  Future<void> publishJob(String jobId) {
    return _request(
      () => _dio.post('/jobs/$jobId/publish'),
      (_) {},
    );
  }

  /// Non-publish status transitions (e.g. closing a live posting from the
  /// list screen). Maps to: PATCH /jobs/:jobId/status ->
  /// updateJobStatus(jobId, companyId, status).
  Future<void> updateJobStatus(String jobId, JobBackendStatus status) {
    return _request(
      () =>
          _dio.patch('/jobs/$jobId/status', data: {'status': status.toJson()}),
      (_) {},
    );
  }

  /// Candidate-facing browse. Maps to: GET /jobs -> listPublishedJobs(query).
  /// Unlike /jobs/mine, this route is already paginated/filterable
  /// server-side (job.dto.ts's listJobsQuerySchema), so filters are sent as
  /// query params rather than applied client-side.
  Future<JobBrowseResult> browseJobs({
    required JobBrowseFilters filters,
    int page = 1,
    int limit = 20,
  }) {
    return _request(
      () => _dio.get('/jobs',
          queryParameters: filters.toQuery(page: page, limit: limit)),
      (data) => JobBrowseResult.fromApiJson(data as Map<String, dynamic>),
    );
  }

  /// Maps to: GET /jobs/:jobId -> getJobById(jobId). Public, unauthenticated
  /// — shared by both the recruiter's and candidate's Job Detail screens
  /// (job_detail_screen.dart), which each layer role-specific actions on
  /// top of the same fetched job.
  Future<JobDetail> getJobDetail(String jobId) {
    return _request(
      () => _dio.get('/jobs/$jobId'),
      (data) => JobDetail.fromApiJson(data as Map<String, dynamic>),
    );
  }

  /// Unwraps the `{ status: 'success', data: ... }` envelope every
  /// job.controller.ts endpoint returns, and turns a DioException into a
  /// plain Exception carrying the backend's error message (e.g. the
  /// "Cannot publish job — missing: ..." AppError text) so callers can
  /// just show e.toString() without digging through response internals.
  Future<T> _request<T>(
    Future<Response> Function() call,
    T Function(dynamic data) map,
  ) async {
    try {
      final response = await call();
      final body = response.data;
      final data = body is Map<String, dynamic> ? body['data'] : body;
      return map(data);
    } on DioException catch (e) {
      final body = e.response?.data;
      final message = _errorMessage(body);
      throw Exception(message ?? _fallbackErrorMessage(e));
    }
  }

  String _fallbackErrorMessage(DioException error) => switch (error.type) {
        DioExceptionType.connectionError =>
          'Could not connect to the server. Check your internet connection and try again.',
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Check your connection and try again.',
        DioExceptionType.cancel =>
          'The request was cancelled. Please try again.',
        DioExceptionType.badResponse =>
          'The server could not complete the request. Please try again.',
        _ => 'Something went wrong. Please try again.',
      };

  String? _errorMessage(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);
    final candidates = [
      map['message'],
      map['error'],
      map['errors'],
      map['issues'],
      if (map['data'] is Map) ...[
        (map['data'] as Map)['message'],
        (map['data'] as Map)['error'],
        (map['data'] as Map)['errors'],
        (map['data'] as Map)['issues'],
      ],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is Map) {
        final nestedMessage = candidate['message'] ?? candidate['detail'];
        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          return nestedMessage.trim();
        }
      }
      if (candidate is List) {
        final messages = candidate
            .map((item) =>
                item is Map ? item['message'] ?? item['detail'] : item)
            .whereType<String>()
            .map((message) => message.trim())
            .where((message) => message.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }
    }
    return null;
  }
}
