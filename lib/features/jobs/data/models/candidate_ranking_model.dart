/// Backs the AI Candidate Ranking screen and parses the backend ranking API.
library;

enum RankingFitLevel { high, medium, low }

RankingFitLevel _fitLevelFromScore(int score) {
  if (score >= 90) return RankingFitLevel.high;
  if (score >= 65) return RankingFitLevel.medium;
  return RankingFitLevel.low;
}

/// One row in the ranked list.
class CandidateRankingEntry {
  const CandidateRankingEntry({
    required this.rank,
    required this.applicationId,
    required this.candidateId,
    required this.name,
    required this.score,
    required this.fitLabel,
    required this.insight,
    this.applicationStatus,
    this.avatarUrl,
    this.experienceYears,
    this.previousCompanies = const [],
    this.strengths = const [],
    this.resumeSummary,
  });

  final int rank;
  final String applicationId; // needed for the row's Message button
  final String? applicationStatus;
  final String candidateId; // needed for the row's Review/profile link
  final String name;
  final String? avatarUrl;

  /// 0-100.
  final int score;

  /// Server-authored short verdict — "Exceptional Fit", "Strong Match",
  /// "Solid Potential", "Balanced Fit", etc. Kept as free text rather than
  /// an enum since the exact vocabulary is the AI ranking prompt's call,
  /// not something the client should constrain.
  final String fitLabel;

  /// 1-2 sentence explanation of the score, shown under the fit label.
  final String insight;

  final int? experienceYears;
  final List<String> previousCompanies;
  final List<String> strengths;
  final Map<String, dynamic>? resumeSummary;

  RankingFitLevel get fitLevel => _fitLevelFromScore(score);

  String get experienceLabel => experienceYears == null
      ? '—'
      : '$experienceYears Year${experienceYears == 1 ? '' : 's'}';

  String get companiesLabel =>
      previousCompanies.isEmpty ? '' : 'Ex-${previousCompanies.join(', ')}';

  factory CandidateRankingEntry.fromApiJson(Map<String, dynamic> json) {
    final candidate = json['candidate'] as Map<String, dynamic>?;
    return CandidateRankingEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      applicationId: (json['applicationId'] ?? '') as String,
      applicationStatus: json['applicationStatus'] as String?,
      candidateId: (candidate?['id'] ?? json['candidateId'] ?? '') as String,
      name:
          (candidate?['name'] ?? json['name'] ?? 'Unknown candidate') as String,
      avatarUrl:
          candidate?['avatarUrl'] as String? ?? json['avatarUrl'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      fitLabel: (json['fitLabel'] ?? json['label'] ?? 'Reviewed') as String,
      insight: (json['insight'] ?? json['explanation'] ?? '') as String,
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      previousCompanies:
          (json['previousCompanies'] as List?)?.cast<String>() ?? const [],
      strengths: (json['strengths'] as List?)?.whereType<String>().toList() ??
          const [],
      resumeSummary: json['resumeSummary'] is Map
          ? Map<String, dynamic>.from(json['resumeSummary'] as Map)
          : null,
    );
  }
}

/// Aggregate statistics and ranked candidates returned by the backend.
class CandidateRankingResult {
  const CandidateRankingResult.empty()
      : totalRanked = 0,
        topTierCount = 0,
        avgMatchScore = 0,
        topSkillLabel = '—',
        topSkillOverlapPercent = 0,
        marketReasoning = const [],
        skillGapReasoning = const [],
        entries = const [],
        isLocked = false,
        summaryEnabled = false,
        rankingEnabled = false,
        aiStatus = 'idle',
        analyzedCount = 0,
        failedCount = 0;

  const CandidateRankingResult({
    required this.totalRanked,
    required this.topTierCount,
    required this.avgMatchScore,
    required this.topSkillLabel,
    required this.topSkillOverlapPercent,
    required this.marketReasoning,
    required this.skillGapReasoning,
    required this.entries,
    this.isLocked = false,
    this.summaryEnabled = false,
    this.rankingEnabled = true,
    this.aiStatus = 'idle',
    this.analyzedCount = 0,
    this.failedCount = 0,
  });

  final int totalRanked;
  final int topTierCount;
  final double avgMatchScore; // percentage, e.g. 74.0
  final String topSkillLabel; // e.g. "React/TS"
  final int topSkillOverlapPercent; // e.g. 92
  final List<String> marketReasoning;
  final List<String> skillGapReasoning;
  final List<CandidateRankingEntry> entries;
  final bool isLocked;
  final bool summaryEnabled;
  final bool rankingEnabled;
  final String aiStatus;
  final int analyzedCount;
  final int failedCount;

  factory CandidateRankingResult.fromApiJson(Map<String, dynamic> json) {
    final rawEntries =
        (json['entries'] as List? ?? json['candidates'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
    final entries = rawEntries.map(CandidateRankingEntry.fromApiJson).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    final skillCounts = <String, int>{};
    var summarizedCandidates = 0;
    for (final entry in entries) {
      final summary = entry.resumeSummary;
      if (summary != null && summary.isNotEmpty) summarizedCandidates++;
      final skills = summary?['skills'] as List? ?? const [];
      for (final skill in skills.whereType<Map>()) {
        final name = skill['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          skillCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
    final commonSkill = skillCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CandidateRankingResult(
      totalRanked: (json['totalRanked'] as num?)?.toInt() ?? entries.length,
      topTierCount: (json['topTierCount'] as num?)?.toInt() ??
          entries.where((e) => e.fitLevel == RankingFitLevel.high).length,
      avgMatchScore: (json['avgMatchScore'] as num?)?.toDouble() ??
          (entries.isEmpty
              ? 0
              : entries.map((e) => e.score).reduce((a, b) => a + b) /
                  entries.length),
      topSkillLabel: commonSkill.isNotEmpty
          ? commonSkill.first.key
          : (json['topSkillLabel'] ?? '—') as String,
      topSkillOverlapPercent: summarizedCandidates == 0
          ? 0
          : ((commonSkill.first.value / summarizedCandidates) * 100).round(),
      marketReasoning:
          (json['marketReasoning'] as List?)?.cast<String>() ?? const [],
      skillGapReasoning:
          (json['skillGapReasoning'] as List?)?.cast<String>() ?? const [],
      entries: entries,
      isLocked: json['locked'] == true,
      summaryEnabled: json['summaryEnabled'] == true,
      rankingEnabled: json['rankingEnabled'] != false,
      aiStatus: (json['aiStatus'] ?? 'idle').toString(),
      analyzedCount: (json['analyzed'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}
