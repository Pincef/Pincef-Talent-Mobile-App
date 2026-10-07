import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'model/dashboard_models.dart';

/// IMPORTANT — read before wiring this to real data.
///
/// The dashboard summary remains mocked while its dependent endpoints are
/// introduced. CV upload is live-wired below, with its endpoint isolated in
/// [cvUploadPath] so it can be corrected when the backend contract is final.
class CandidateDashboardRepository {
  CandidateDashboardRepository(this._dio);

  final Dio _dio;

  /// Replace this path (and, if needed, the `cv` field name) when the
  /// candidate CV endpoint is finalized. The file is sent as multipart/form-data.
  static const cvUploadPath = '/candidate-profile/cv';

  Future<void> uploadCv(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError(
          'The selected file could not be read. Please try again.');
    }

    await _dio.post(
      cvUploadPath,
      data: FormData.fromMap({
        'cv': MultipartFile.fromBytes(bytes, filename: file.name),
      }),
    );
  }

  Future<DashboardSummary> loadDashboard() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return const DashboardSummary(
      careerHighlights: [
        'Led redesign of fintech dashboard increasing retention by 24%',
        'Architected design system used by 50+ cross-functional teams',
      ],
      coreStrengths: [
        'Product Strategy',
        'User-Centric Design',
        'Rapid Prototyping'
      ],
      workExperience: WorkExperienceSummary(
        yearsOfExperience: 6.5,
        title: 'Senior UI/UX Designer',
        company: 'Global Tech Corp',
        period: '2020 - Present',
        description:
            'Leading the design of enterprise-scale financial dashboards and internal tooling.',
      ),
      applications: [
        CandidateDashboardApplication(
            jobTitle: 'Senior Product Designer',
            company: 'Global Tech Corp',
            appliedLabel: 'Applied 4 days ago',
            statusLabel: 'INTERVIEWING',
            currentStage: ApplicationStage.technical,
            progressPercent: 0.75),
        CandidateDashboardApplication(
            jobTitle: 'UI Engineer',
            company: 'InnovaSoft',
            appliedLabel: 'Applied 12 days ago',
            statusLabel: 'APPLICATION SENT',
            currentStage: ApplicationStage.applied,
            progressPercent: 0.15),
      ],
      recentUploads: [
        RecentUpload(
            fileName: 'resume_v3_ux.pdf',
            uploadedLabel: 'Uploaded today, 10:45 AM',
            status: UploadStatus.parsing),
        RecentUpload(
            fileName: 'resume_2023_main.pdf',
            uploadedLabel: 'Uploaded Jan 14, 2024',
            status: UploadStatus.ready),
      ],
      jobMatches: [
        JobMatch(
            title: 'Lead Product Designer',
            company: 'Stripe',
            workMode: 'Remote',
            salaryRange: '\$180k - \$220k',
            matchPercent: 98,
            tags: ['Fintech', 'System Design']),
        JobMatch(
            title: 'Senior UX Researcher',
            company: 'Linear',
            workMode: 'Hybrid',
            salaryRange: '\$160k - \$190k',
            matchPercent: 92,
            tags: ['B2B SaaS', 'Strategy']),
      ],
      workspaceTip:
          'Update your portfolio link to increase your AI Match score by up to 12%.',
    );
  }
}
