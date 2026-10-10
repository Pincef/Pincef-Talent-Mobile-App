/// Backs the AI Candidate Ranking screen. Deliberately parsed defensively
/// (lots of `as? / ??`) — this model is written ahead of the actual
/// ranking endpoint's contract, which isn't built yet. Tighten the nullable
/// fields once that contract is confirmed.
library;

enum RankingFitLevel { high, medium, low }

RankingFitLevel _fitLevelFromScore(int score) {
  if (score >= 85) return RankingFitLevel.high;
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
    this.avatarUrl,
    this.experienceYears,
    this.previousCompanies = const [],
  });

  final int rank;
  final String applicationId; // needed for the row's Message button
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
    );
  }
}

/// The full ranking result for a job — aggregate stats, the "reasoning"
/// callouts, and the ranked list itself. Nothing here is saved to the
/// database: it's recomputed fresh every time the screen asks for it,
/// since candidates can apply to the job at any moment and a cached
/// ranking would go stale immediately.
class CandidateRankingResult {
  const CandidateRankingResult.empty()
      : totalRanked = 0,
        topTierCount = 0,
        avgMatchScore = 0,
        topSkillLabel = '—',
        topSkillOverlapPercent = 0,
        marketReasoning = const [],
        skillGapReasoning = const [],
        entries = const [];

  const CandidateRankingResult({
    required this.totalRanked,
    required this.topTierCount,
    required this.avgMatchScore,
    required this.topSkillLabel,
    required this.topSkillOverlapPercent,
    required this.marketReasoning,
    required this.skillGapReasoning,
    required this.entries,
  });

  final int totalRanked;
  final int topTierCount;
  final double avgMatchScore; // percentage, e.g. 74.0
  final String topSkillLabel; // e.g. "React/TS"
  final int topSkillOverlapPercent; // e.g. 92
  final List<String> marketReasoning;
  final List<String> skillGapReasoning;
  final List<CandidateRankingEntry> entries;

  factory CandidateRankingResult.fromApiJson(Map<String, dynamic> json) {
    final rawEntries =
        (json['entries'] as List? ?? json['candidates'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
    final entries = rawEntries.map(CandidateRankingEntry.fromApiJson).toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return CandidateRankingResult(
      totalRanked: (json['totalRanked'] as num?)?.toInt() ?? entries.length,
      topTierCount: (json['topTierCount'] as num?)?.toInt() ??
          entries.where((e) => e.fitLevel == RankingFitLevel.high).length,
      avgMatchScore: (json['avgMatchScore'] as num?)?.toDouble() ??
          (entries.isEmpty
              ? 0
              : entries.map((e) => e.score).reduce((a, b) => a + b) /
                  entries.length),
      topSkillLabel: (json['topSkillLabel'] ?? '—') as String,
      topSkillOverlapPercent:
          (json['topSkillOverlapPercent'] as num?)?.toInt() ?? 0,
      marketReasoning:
          (json['marketReasoning'] as List?)?.cast<String>() ?? const [],
      skillGapReasoning:
          (json['skillGapReasoning'] as List?)?.cast<String>() ?? const [],
      entries: entries,
    );
  }
}
