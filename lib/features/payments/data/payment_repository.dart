/// Temporary source for subscription plans.
///
/// Keep API integration here when billing is connected; the presentation layer
/// only depends on the shape returned by this repository.
class PaymentRepository {
  Future<List<SubscriptionPlan>> getPlans() async => const [
        SubscriptionPlan(
          id: 'free',
          name: 'FREE PLAN',
          description: 'Basic access for occasional lightweight hiring needs.',
          monthlyPrice: 0,
          features: ['2 active jobs', 'Standard job posting', 'Candidate management', 'No AI-powered tools'],
        ),
        SubscriptionPlan(
          id: 'starter',
          name: 'STARTER',
          description: 'For small businesses just starting structured recruitment.',
          monthlyPrice: 15000,
          features: ['5 active jobs', 'CV screening', 'AI CV parsing & resume summaries', 'Basic matching scoring', 'No competency assessments'],
        ),
        SubscriptionPlan(
          id: 'professional',
          name: 'PROFESSIONAL',
          description: 'For growing agencies and growing organisations.',
          monthlyPrice: 35000,
          featured: true,
          features: ['10–15 active jobs', '500 CVs / month', 'Shortlist features', 'AI CV-to-job matching', 'Candidate ranking', 'Competency assessment', 'Candidate comparison', 'Recruitment reports'],
        ),
        SubscriptionPlan(
          id: 'business',
          name: 'BUSINESS',
          description: 'For agencies and high-volume enterprise recruitment.',
          monthlyPrice: 75000,
          features: ['Unlimited active jobs', '1,500+ CVs/month', 'AI resume parsing', 'Automated screening & pipelines', 'Team users & API integration', 'Priority 24/7 support'],
        ),
      ];
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int monthlyPrice;
  final List<String> features;
  final bool featured;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.features,
    this.featured = false,
  });
}
