import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Display metadata for a backend `StageType`. Keys are UPPER-CASED enum
/// names. Any type the server returns that isn't listed here still renders
/// (prettified label + generic icon), so adding a new StageType on the
/// backend never breaks the app.
///
/// TODO: match these keys to the values in `payment/plan.type.ts`.
class StageTypeMeta {
  const StageTypeMeta(this.label, this.icon, this.blurb);
  final String label;
  final IconData icon;
  final String blurb;
}

const Map<String, StageTypeMeta> kStageTypeMeta = {
  'APPLIED': StageTypeMeta('Application', Icons.description_outlined,
      'Standard application portal, sourcing UTMs & resume ingest.'),
  'CV_PARSING': StageTypeMeta('Parse', Icons.description_outlined,
      'Extract structured candidate details from the uploaded CV.'),
  'AI_MATCHING': StageTypeMeta('Match', Icons.auto_awesome_outlined,
      'Compare candidate experience and skills with the job requirements.'),
  'AI_RANKING': StageTypeMeta('Rank', Icons.leaderboard_outlined,
      'Order completed matches by job fit.'),
  'AI_SUMMARY': StageTypeMeta('Summarise', Icons.summarize_outlined,
      'Create a recruiter-facing summary of each candidate.'),
  'COMPARE': StageTypeMeta('Compare', Icons.compare_arrows_outlined,
      'Review shortlisted candidates side by side.'),
  'SCREENING': StageTypeMeta('Screening', Icons.fact_check_outlined,
      'Initial recruiter screening scorecard and experience validation.'),
  'ASSESSMENT': StageTypeMeta('Assessment', Icons.assignment_outlined,
      'Structured assessment attached per job requisition.'),
  'INTERVIEW': StageTypeMeta('Interview', Icons.forum_outlined,
      'Panel or one-to-one interview with a scorecard.'),
  'OFFER': StageTypeMeta('Offer', Icons.handshake_outlined,
      'Compensation alignment and formal offer draft.'),
  'HIRED': StageTypeMeta('Hired', Icons.verified_outlined,
      'Candidate accepted and is onboarding.'),
  'REJECTED': StageTypeMeta(
      'Rejected', Icons.block_outlined, 'Candidate exited the process.'),
};

String _prettify(String raw) => raw
    .toLowerCase()
    .split(RegExp(r'[_\s]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

StageTypeMeta stageMetaFor(String type) =>
    kStageTypeMeta[type.toUpperCase()] ??
    StageTypeMeta(
        _prettify(type), Icons.flag_outlined, 'Custom pipeline gate.');

bool isAssessmentType(String type) => type.toUpperCase().contains('ASSESSMENT');

/// Client display flow for the built-in pipelines. Candidate progression is
/// still owned by the API; this is the job-specific flow the recruiter chose.
List<String> hiringPipelineFlowFor(
  String tier, {
  List<PipelineStage> customStages = const [],
}) {
  const aiStages = ['Post Job', 'Parse', 'Match', 'Rank', 'Summarise'];
  switch (tier.toLowerCase()) {
    case 'premium':
      return [...aiStages, 'Assess', 'Compare', 'Hire'];
    case 'custom':
      final configured = customStages
          .where((stage) => stage.type.toUpperCase() != 'APPLIED')
          .map((stage) => stage.name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (configured.isEmpty) return [...aiStages, 'Custom stages', 'Hire'];
      if (!configured.any((name) => name.toLowerCase() == 'hire')) {
        configured.add('Hire');
      }
      return [...aiStages, ...configured];
    default:
      return [...aiStages, 'Hire'];
  }
}

class PipelineStage {
  const PipelineStage({
    required this.type,
    required this.name,
    required this.order,
    this.isRequired = true,
    this.description = '',
    this.assessmentMode = 'ai',
    this.interviewMode = 'manual',
    this.automationReviewHours = 24,
    this.passingScore = 75,
    this.durationMins = 60,
  });

  /// Raw backend enum value. Always send back exactly what the server uses.
  final String type;
  final String name;
  final int order;

  // Client-side only until the backend stores them (see repository flag).
  final bool isRequired;
  final String description;
  final String assessmentMode; // ai | manual | auto
  final String interviewMode; // manual | auto
  final int automationReviewHours;
  final int passingScore;
  final int durationMins;

  factory PipelineStage.fromJson(Map<String, dynamic> json) {
    final cfg = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : const <String, dynamic>{};
    return PipelineStage(
      type: json['type'].toString(),
      name: (json['name'] ?? '').toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      isRequired: json['required'] as bool? ?? true,
      description: (json['description'] ?? '').toString(),
      assessmentMode: (cfg['assessmentMode'] ?? 'ai').toString(),
      interviewMode: (cfg['interviewMode'] ?? 'manual').toString(),
      automationReviewHours:
          (cfg['automationReviewHours'] as num?)?.toInt() ?? 24,
      passingScore: (cfg['passingScore'] as num?)?.toInt() ?? 75,
      durationMins: (cfg['durationMins'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toRequestJson({required bool extended}) => {
        'type': type,
        'name': name,
        if (extended) ...{
          'required': isRequired,
          'description': description,
          if (isAssessmentType(type))
            'config': {
              'assessmentMode': assessmentMode,
              'passingScore': passingScore,
              'durationMins': durationMins,
            },
          if (type.toUpperCase() == 'INTERVIEW')
            'config': {
              'interviewMode': interviewMode,
              'automationReviewHours': automationReviewHours,
            },
        },
      };
}

class HiringPipeline {
  const HiringPipeline({
    required this.id,
    required this.name,
    required this.isSystemStandard,
    this.isSystemPremium = false,
    required this.stages,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.status,
    this.codeFromServer,
    this.jobCount = 0,
    this.candidateCount = 0,
  });

  final String id;
  final String name;
  final bool isSystemStandard;
  final bool isSystemPremium;
  final List<PipelineStage> stages;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Not returned by the backend yet — all optional with safe defaults.
  final String description;
  final String? status; // draft | active | locked
  final String? codeFromServer;
  final int jobCount;
  final int candidateCount;

  /// ACTIVE | DRAFT | LOCKED. The system-standard pipeline can't be edited
  /// or deleted server-side, so it is presented as locked.
  String get state {
    if (isSystemStandard || isSystemPremium || candidateCount > 0) {
      return 'LOCKED';
    }
    final s = (status ?? 'active').toUpperCase();
    return s == 'DRAFT' ? 'DRAFT' : (s == 'LOCKED' ? 'LOCKED' : 'ACTIVE');
  }

  bool get isLocked => state == 'LOCKED';

  String get code =>
      codeFromServer ??
      'PL-${id.substring(math.max(0, id.length - 6)).toUpperCase()}';

  factory HiringPipeline.fromJson(Map<String, dynamic> json) {
    DateTime parse(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final stages = ((json['stages'] as List?) ?? const [])
        .map((e) => PipelineStage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return HiringPipeline(
      id: (json['_id'] ?? json['id']).toString(),
      name: (json['name'] ?? '').toString(),
      isSystemStandard: json['isSystemStandard'] as bool? ?? false,
      isSystemPremium: json['isSystemPremium'] as bool? ?? false,
      stages: stages,
      createdAt: parse(json['createdAt']),
      updatedAt: parse(json['updatedAt']),
      description: (json['description'] ?? '').toString(),
      status: json['status']?.toString(),
      codeFromServer: json['code']?.toString(),
      jobCount: (json['jobCount'] as num?)?.toInt() ?? 0,
      candidateCount: (json['candidateCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toExportJson() => {
        'name': name,
        'code': code,
        'state': state,
        'stages': [
          for (final s in stages)
            {'order': s.order, 'type': s.type, 'name': s.name},
        ],
      };
}

/// Mirrors GET /hiring-pipelines/capabilities.
class PipelineCapabilities {
  const PipelineCapabilities({
    required this.plan,
    required this.allowedStageTypes,
    required this.allowsCustomPipelines,
    required this.maxCustomPipelines,
  });

  final String plan;
  final List<String> allowedStageTypes;
  final bool allowsCustomPipelines;
  final int maxCustomPipelines;

  factory PipelineCapabilities.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'] is Map
        ? Map<String, dynamic>.from(json['capabilities'] as Map)
        : const <String, dynamic>{};
    return PipelineCapabilities(
      plan: (json['plan'] ?? '').toString(),
      allowedStageTypes: ((caps['allowedStageTypes'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      allowsCustomPipelines: caps['allowsCustomPipelines'] as bool? ?? true,
      maxCustomPipelines: (caps['maxCustomPipelines'] as num?)?.toInt() ?? 999,
    );
  }

  factory PipelineCapabilities.fromEntitlements(
          Map<String, dynamic> capabilities) =>
      PipelineCapabilities.fromJson({'capabilities': capabilities});

  /// If the server sent no list, don't block anything client-side — the
  /// backend enforces the plan on save anyway.
  bool allows(String type) =>
      allowedStageTypes.isEmpty ||
      allowedStageTypes.any((t) => t.toUpperCase() == type.toUpperCase());

  /// Returns the server's exact spelling for a stage type (case-safe).
  String resolve(String type) => allowedStageTypes.firstWhere(
        (t) => t.toUpperCase() == type.toUpperCase(),
        orElse: () => type,
      );
}
