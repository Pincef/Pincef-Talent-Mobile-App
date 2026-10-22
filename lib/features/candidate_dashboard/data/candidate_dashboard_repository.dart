import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'model/dashboard_models.dart';

class CandidateDashboardRepository {
  CandidateDashboardRepository(this._dio);

  final Dio _dio;
  static const cvUploadPath = '/candidate-profile/cv';

  Future<void> uploadCv(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError(
          'The selected file could not be read. Please try again.');
    }
    await _dio.post(cvUploadPath,
        data: FormData.fromMap({
          'cv': MultipartFile.fromBytes(bytes, filename: file.name),
        }));
  }

  Future<DashboardSummary> loadDashboard() async {
    final responses = await Future.wait([
      _dio.get('/candidate-profile/me'),
      _dio.get('/applications/me', queryParameters: {'limit': 100}),
      _dio.get('/jobs', queryParameters: {'page': 1, 'limit': 6}),
    ]);
    final profile = _object(_payload(responses[0].data));
    final applicationsPayload = _payload(responses[1].data);
    final rawApplications = applicationsPayload is List
        ? applicationsPayload
        : applicationsPayload is Map
            ? applicationsPayload['applications'] as List? ?? const []
            : const [];
    final rawExperience = profile['experience'] as List? ?? const [];
    final experiences = rawExperience.whereType<Map>().toList();
    final currentExperience = experiences.cast<Map?>().firstWhere(
          (entry) => entry != null && entry['endDate'] == null,
          orElse: () => experiences.isEmpty ? null : experiences.first,
        );
    final skills = (profile['skills'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final highlights = <String>[];
    final summary = (profile['bio'] ?? profile['aiSummary'])?.toString().trim();
    if (summary != null && summary.isNotEmpty) highlights.add(summary);
    for (final entry in experiences) {
      for (final achievement in (entry['achievements'] as List? ?? const [])) {
        final text = achievement.toString().trim();
        if (text.isNotEmpty && !highlights.contains(text)) highlights.add(text);
      }
    }
    final cvFiles =
        (profile['cvFiles'] as List? ?? const []).whereType<Map>().toList();
    final applications = rawApplications.whereType<Map>().map((row) {
      final job = _object(row['jobId']);
      final company = _object(job['companyId']);
      final status = (row['status'] ?? 'submitted').toString();
      final appliedAt = DateTime.tryParse((row['appliedAt'] ?? '').toString());
      final days = appliedAt == null
          ? null
          : DateTime.now().difference(appliedAt).inDays;
      return CandidateDashboardApplication(
        jobTitle: (job['title'] ?? 'Job').toString(),
        company: (company['name'] ?? 'Company').toString(),
        appliedLabel: days == null
            ? 'Application submitted'
            : 'Applied ${days == 0 ? 'today' : '$days days ago'}',
        statusLabel: status.replaceAll('_', ' ').toUpperCase(),
        currentStage: _stageFor(status),
        progressPercent: _progressFor(status),
      );
    }).toList();
    final browsePayload = _object(_payload(responses[2].data));
    final rawJobs = browsePayload['jobs'] as List? ?? const [];
    final matches = rawJobs.whereType<Map>().map((row) {
      final company = _object(row['companyId']);
      final min = row['minSalary'];
      final max = row['maxSalary'];
      final currency = (row['currency'] ?? 'USD').toString();
      final salary = min == null && max == null
          ? 'Salary not disclosed'
          : '$currency ${min ?? ''}${min != null && max != null ? ' – ' : ''}${max ?? '+'}';
      return JobMatch(
        title: (row['title'] ?? 'Untitled role').toString(),
        company: (company['name'] ?? 'Company').toString(),
        workMode: (row['workplaceType'] ?? 'Not specified')
            .toString()
            .replaceAll('_', ' '),
        salaryRange: salary,
        matchPercent: null,
        tags: (row['requiredSkills'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
    }).toList();
    final firstName = currentExperience?['title']?.toString();
    final start =
        DateTime.tryParse((currentExperience?['startDate'] ?? '').toString());
    final years = start == null
        ? 0
        : (DateTime.now().difference(start).inDays / 365.25).floor();
    final location = _object(profile['location']);
    final locationLabel = [
      location['city'],
      location['stateName'],
      location['countryName']
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
    return DashboardSummary(
      careerHighlights: highlights,
      coreStrengths: skills,
      workExperience: WorkExperienceSummary(
        yearsOfExperience: years,
        title: firstName ??
            (profile['professionalTitle'] ?? 'Add a professional title')
                .toString(),
        company: (currentExperience?['company'] ?? '').toString(),
        period: start == null
            ? ''
            : '${DateFormat('yyyy').format(start)} – ${currentExperience?['endDate'] == null ? 'Present' : DateFormat('yyyy').format(DateTime.tryParse(currentExperience!['endDate'].toString()) ?? start)}',
        description: (currentExperience?['description'] ?? '').toString(),
      ),
      applications: applications,
      recentUploads: cvFiles.map((file) {
        final uploaded =
            DateTime.tryParse((file['uploadedAt'] ?? '').toString());
        return RecentUpload(
          fileName: (file['originalName'] ?? file['name'] ?? 'CV').toString(),
          uploadedLabel: uploaded == null
              ? 'Uploaded'
              : 'Uploaded ${DateFormat.yMMMd().format(uploaded)}',
          status: UploadStatus.ready,
        );
      }).toList(),
      jobMatches: matches,
      workspaceTip: locationLabel.isEmpty
          ? 'Add your location to help recruiters find relevant opportunities.'
          : 'Your profile location is $locationLabel.',
    );
  }

  static dynamic _payload(dynamic body) =>
      body is Map && body.containsKey('data') ? body['data'] : body;
  static Map<String, dynamic> _object(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static ApplicationStage _stageFor(String status) => switch (status) {
        'submitted' => ApplicationStage.applied,
        'shortlisted' => ApplicationStage.screening,
        'interviewing' || 'offered' => ApplicationStage.technical,
        'hired' => ApplicationStage.finalStage,
        _ => ApplicationStage.applied,
      };
  static double _progressFor(String status) => switch (status) {
        'submitted' => .15,
        'shortlisted' => .4,
        'interviewing' => .65,
        'offered' => .85,
        'hired' => 1,
        _ => .15,
      };
}
