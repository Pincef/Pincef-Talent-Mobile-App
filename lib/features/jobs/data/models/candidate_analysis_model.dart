/// lib/features/jobs/data/models/candidate_job_analysis_model.dart
///
/// Mirrors candidateJobAnalysis.model.ts's ICandidateJobAnalysis — just the
/// fields the profile preview screen's "Smart Match Insights" card needs.
enum CandidateJobAnalysisStatus { pending, processing, completed, failed }

CandidateJobAnalysisStatus _statusFromJson(String value) => switch (value) {
      'processing' => CandidateJobAnalysisStatus.processing,
      'completed' => CandidateJobAnalysisStatus.completed,
      'failed' => CandidateJobAnalysisStatus.failed,
      _ => CandidateJobAnalysisStatus.pending,
    };

class CandidateJobAnalysis {
  const CandidateJobAnalysis({
    required this.status,
    this.score,
    this.summary,
    this.error,
  });

  final CandidateJobAnalysisStatus status;
  final int? score; // 0-100
  final String? summary;
  final String? error;

  factory CandidateJobAnalysis.fromJson(Map<String, dynamic> json) {
    return CandidateJobAnalysis(
      status: _statusFromJson(json['status'] as String? ?? 'pending'),
      score: (json['score'] as num?)?.toInt(),
      summary: json['summary'] as String?,
      error: json['error'] as String?,
    );
  }
}
