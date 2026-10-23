import 'package:dio/dio.dart';
import 'models/application_model.dart';

/// Handles applying to jobs, plus the small slice of the candidate's
/// CandidateProfile (cvFiles) needed for the "which CV?" picker on the Job
/// Detail screen. That CV lookup arguably belongs to a dedicated
/// candidate-profile repository — if one already exists elsewhere in the
/// app (e.g. behind cv_upload_modal.dart), prefer wiring job_detail_screen.dart
/// to that instead of this one, to avoid two sources of truth for the same
/// data. Kept here for now since none was available to reuse.
///
/// Also handles the recruiter-facing side: fetching the applicants for a
/// job (getJobApplications), which is what powers job_candidates_screen.dart.
class ApplicationsRepository {
  ApplicationsRepository(this._dio);

  final Dio _dio;

  /// Maps to: POST /applications -> createApplication(candidateId, jobId, cvPublicId).
  /// [cvPublicId] is only required when the candidate has more than one CV
  /// on file (application.service.ts's resolveCvForApplication) — the
  /// screen is expected to check getMyCvFiles() first and only prompt for
  /// a choice when there's actually more than one.
  Future<ApplicationSummary> apply(String jobId, {String? cvPublicId}) async {
    try {
      final response = await _dio.post('/applications', data: {
        'jobId': jobId,
        if (cvPublicId != null) 'cvPublicId': cvPublicId,
      });
      final body = response.data as Map<String, dynamic>;
      final application = Map<String, dynamic>.from(body['data'] as Map);
      application['receiptEmailSent'] =
          (body['meta'] as Map?)?['receiptEmailSent'] == true;
      return ApplicationSummary.fromApiJson(application);
    } on DioException catch (e) {
      final body = e.response?.data;
      final message =
          body is Map<String, dynamic> ? body['message'] as String? : null;
      throw Exception(message ?? e.message ?? 'Request failed');
    }
  }

  /// Maps to: GET /applications/me -> getMyApplications(candidateId, {page,limit}).
  /// Used for correctness-sensitive checks (e.g. "have I already applied
  /// to this job") where silently truncating the list would be a real
  /// bug, not just a display issue — so this asks for a generous page
  /// size (100) rather than the default 20, and unwraps just the
  /// `applications` array from the now-paginated response. If a candidate
  /// could plausibly have more than 100 applications, raise this or
  /// switch that call site to page through [getMyApplicationsPage] instead.
  Future<List<ApplicationSummary>> getMyApplications() {
    return _request(
      () => _dio.get('/applications/me', queryParameters: {'limit': 100}),
      (data) =>
          MyApplicationsPage.fromApiJson(data, fallbackPage: 1).applications,
    );
  }

  /// Paginated version of the candidate's application history — backs
  /// MyApplicationsNotifier's "load more".
  Future<MyApplicationsPage> getMyApplicationsPage({
    int page = 1,
    int limit = 20,
  }) {
    return _request(
      () => _dio.get(
        '/applications/me',
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) => MyApplicationsPage.fromApiJson(data, fallbackPage: page),
    );
  }

  /// Maps to: GET /candidate-profile/me -> candidateProfileService.getMyProfile.
  /// Only pulls cvFiles out of the full profile response — see the class
  /// doc comment above about a possible dedicated repository for this.
  Future<List<CvFileOption>> getMyCvFiles() {
    return _request(
      () => _dio.get('/candidate-profile/me'),
      (data) {
        final profile = data as Map<String, dynamic>;
        final cvFiles =
            (profile['cvFiles'] as List?)?.cast<Map<String, dynamic>>() ??
                const [];
        return cvFiles.map(CvFileOption.fromApiJson).toList();
      },
    );
  }

  /// Recruiter-facing: paginated applicants for one job.
  ///
  /// Maps to: GET /applications/job/:jobId?page=&limit= ->
  /// getApplicationsForJob(jobId, companyId, page, limit). companyId isn't
  /// passed from here — same as JobManagementRepository, it's derived
  /// server-side from the auth token DioClient attaches to every request,
  /// which is also what scopes this to the recruiter's own company so one
  /// recruiter can't page through another company's applicants by jobId
  /// alone.
  Future<JobApplicantsPage> getJobApplications(
    String jobId, {
    int page = 1,
    int limit = 20,
  }) {
    return _request(
      () => _dio.get(
        '/applications/job/$jobId',
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) => JobApplicantsPage.fromApiJson(data as Map<String, dynamic>),
    );
  }

  /// Sends an interview invite email for one application and moves it to
  /// INTERVIEWING server-side. `subject`/`body` may contain {tokens} — see
  /// [getInviteTokens] — the backend merges them with the real candidate/
  /// job/company data, never trusting rendered content from the client.
  ///
  /// Maps to: POST /applications/:applicationId/send-invite ->
  /// sendInterviewInvite(applicationId, companyId, recruiterId, input).
  Future<JobApplicantSummary> sendInterviewInvite(
    String applicationId, {
    required String subject,
    required String body,
    String? inviteType,
  }) {
    return _request(
      () => _dio.post('/applications/$applicationId/send-invite', data: {
        'subject': subject,
        'body': body,
        if (inviteType != null && inviteType.isNotEmpty)
          'inviteType': inviteType,
      }),
      (data) => JobApplicantSummary.fromApiJson(data as Map<String, dynamic>),
    );
  }

  /// Sends a selected recruiter's email template to the candidate without
  /// changing the application status or hiring stage.
  Future<void> sendCandidateEmail(
    String applicationId, {
    required String templateName,
    required String subject,
    required String body,
  }) async {
    await _request<bool>(
      () => _dio.post('/applications/$applicationId/send-email', data: {
        'templateName': templateName,
        'subject': subject,
        'body': body,
      }),
      (data) {
        if (data is Map && data['sent'] == true) return true;
        throw Exception('Email service did not confirm delivery');
      },
    );
  }

  /// Recruiter shortlist/reject decision. Rejections send the standard
  /// application update email on the backend; the response reports delivery.
  Future<bool> updateApplicationStatus(
    String applicationId,
    ApplicationBackendStatus status,
  ) {
    return _request(
      () => _dio.patch('/applications/$applicationId/status', data: {
        'status': switch (status) {
          ApplicationBackendStatus.submitted => 'submitted',
          ApplicationBackendStatus.shortlisted => 'shortlisted',
          ApplicationBackendStatus.interviewing => 'interviewing',
          ApplicationBackendStatus.offered => 'offered',
          ApplicationBackendStatus.rejected => 'rejected',
          ApplicationBackendStatus.hired => 'hired',
        },
      }),
      (data) => data is Map<String, dynamic>
          ? (data['statusEmailSent'] == true ||
              data['rejectionEmailSent'] == true)
          : false,
    );
  }

  /// The token names available to insert into an invite's subject/body
  /// (e.g. "jobTitle", "CompanyName") — fetched rather than hardcoded so
  /// this can't drift from what sendInterviewInvite actually renders.
  ///
  /// Maps to: GET /applications/invite-tokens.
  Future<List<String>> getInviteTokens() {
    return _request(
      () => _dio.get('/applications/invite-tokens'),
      (data) => (data as List).cast<String>(),
    );
  }

  /// Same unwrap-and-rethrow pattern as JobManagementRepository._request —
  /// unwraps the `{ status: 'success', data: ... }` envelope and turns a
  /// DioException into a plain Exception carrying the backend's message
  /// (e.g. "You have more than one CV on file — select which one to use",
  /// or "You have already applied to this job").
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
      final message =
          body is Map<String, dynamic> ? body['message'] as String? : null;
      throw Exception(message ?? e.message ?? 'Request failed');
    }
  }
}
