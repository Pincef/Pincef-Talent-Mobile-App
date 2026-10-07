/// Backend module codes returned on the authenticated user/session.
///
/// Add new module codes here as mobile features begin to use them. The values
/// intentionally match the backend strings exactly.
abstract final class ModuleCodes {
  static const jobPipeline = 'job.pipeline';
  static const jobPipelinePremium = 'job.pipeline.premium';
  static const jobPipelineCustom = 'job.pipeline.custom';
  static const jobsPlanAutomation = 'jobs.plan_automation';
  static const jobsUnlimitedPost = 'jobs.unlimited_post';
  static const jobsBoost = 'jobs.boost';
  static const analyticsAdvanced = 'analytics.advanced';
  static const analyticsBasic = 'analytics.basic';
  static const aiCandidateMatch = 'ai.candidate_match';
  static const aiCandidateSummary = 'ai.candidate_summary';
  static const aiCandidateInterview = 'ai.candidate_interview';
  static const aiCandidateEngagement = 'ai.candidate_engagement';
  static const aiCandidateOutreach = 'ai.candidate_outreach';
  static const aiCandidateOutreachTemplates = 'ai.candidate_outreach_templates';
  static const aiCandidateOutreachScheduling =
      'ai.candidate_outreach_scheduling';
  static const aiCandidateOutreachAnalytics = 'ai.candidate_outreach_analytics';
  static const aiCandidateOutreachPersonalization =
      'ai.candidate_outreach_personalization';
  static const aiCandidateOutreachAbTesting =
      'ai.candidate_outreach_a_b_testing';
  static const aiCandidateOutreachMultiChannel =
      'ai.candidate_outreach_multi_channel';
  static const aiCandidateOutreachIntegrations =
      'ai.candidate_outreach_integrations';
  static const aiCandidateOutreachAutomation =
      'ai.candidate_outreach_automation';
  static const aiCandidateOutreachCustomization =
      'ai.candidate_outreach_customization';
  static const aiCandidateOutreachReporting = 'ai.candidate_outreach_reporting';
  static const aiCandidateOutreachSecurity = 'ai.candidate_outreach_security';
  static const teamExtraSeats = 'team.extra_seats';
  static const hiringPipeline = 'hiring.pipeline';
  static const aiCvParsing = 'ai.cv_parsing';
  static const aiJobDescriptionGeneration = 'ai.job_description_generation';
  static const hiringStageInterview = 'hiring.stage.interview';
  static const hiringStageAssessment = 'hiring.stage.assessment';
}
