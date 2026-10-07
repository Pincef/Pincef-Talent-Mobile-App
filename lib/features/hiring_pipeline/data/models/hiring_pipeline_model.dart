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

class PipelineStage {
  const PipelineStage({
    required this.type,
    required this.name,
    required this.order,
    this.isRequired = true,
    this.description = '',
    this.assessmentMode = 'ai',
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
        },
      };
}

class HiringPipeline {
  const HiringPipeline({
    required this.id,
    required this.name,
    required this.isSystemStandard,
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
    if (isSystemStandard || candidateCount > 0) return 'LOCKED';
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
