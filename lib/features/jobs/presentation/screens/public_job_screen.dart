import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../onboarding/application/selected_role_provider.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';

/// Public, read-only job description page intended for recipients of a share
/// link. It deliberately lives outside the authenticated app shell.
class PublicJobScreen extends ConsumerWidget {
  const PublicJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: jobAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _PublicState(
                title: 'Job unavailable',
                message: 'This job link may be invalid or no longer active.',
                action: TextButton(
                  onPressed: () => ref.invalidate(jobDetailProvider(jobId)),
                  child: const Text('Try again'),
                ),
              ),
              data: (job) => job.status != JobBackendStatus.published
                  ? const _PublicState(
                      title: 'Job unavailable',
                      message: 'This job is no longer accepting applications.',
                    )
                  : _PublicJobContent(
                      job: job,
                      onApply: () {
                        if (user?.role == UserRole.candidate) {
                          context.go('/jobs/$jobId');
                          return;
                        }
                        if (user != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Sign in with a candidate account to apply.'),
                            ),
                          );
                          return;
                        }
                        ref.read(selectedRoleProvider.notifier).state =
                            UserRole.candidate;
                        context.go(Uri(
                          path: '/signup',
                          queryParameters: {
                            'returnTo': '/shared/jobs/$jobId',
                          },
                        ).toString());
                      },
                      applyLabel: user == null
                          ? 'Create an account to apply'
                          : user.role == UserRole.candidate
                              ? 'Continue to apply'
                              : 'Candidate account required',
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicState extends StatelessWidget {
  const _PublicState({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.work_outline, size: 36, color: BrandColors.muted),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.navy)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BrandColors.muted)),
          if (action != null) action!,
        ]),
      );
}

class _PublicJobContent extends StatelessWidget {
  const _PublicJobContent({
    required this.job,
    required this.onApply,
    required this.applyLabel,
  });

  final JobDetail job;
  final VoidCallback onApply;
  final String applyLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final contentWidth = (constraints.maxWidth - (compact ? 28 : 48))
          .clamp(0, 1072)
          .toDouble();
      final columns = contentWidth >= 800 ? 2 : 1;
      final cardWidth = (contentWidth - (columns - 1) * 14) / columns;
      final detailCards = <Widget>[];
      if (job.responsibilities.isNotEmpty) {
        detailCards.add(SizedBox(
            width: cardWidth,
            child: _Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _SectionTitle('Responsibilities'),
                  const SizedBox(height: 12),
                  for (final item in job.responsibilities) _Bullet(text: item),
                ]))));
      }
      if (job.requiredSkills.isNotEmpty ||
          (job.minYearsOfExperience?.isNotEmpty ?? false) ||
          job.educationLevelLabel != null ||
          job.requiresManagementExperience) {
        detailCards.add(SizedBox(
            width: cardWidth,
            child: _Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _SectionTitle('Skills and requirements'),
                  if (job.requiredSkills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final skill in job.requiredSkills)
                        Chip(
                          label: Text(skill),
                          backgroundColor: const Color(0xFFF3F5F8),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                    ]),
                  ],
                  if (job.minYearsOfExperience != null ||
                      job.educationLevelLabel != null ||
                      job.requiresManagementExperience) ...[
                    const SizedBox(height: 10),
                    if (job.minYearsOfExperience?.isNotEmpty ?? false)
                      _Bullet(text: '${job.minYearsOfExperience} experience'),
                    if (job.educationLevelLabel != null)
                      _Bullet(
                          text:
                              'Education: ${job.educationLevelLabel}${job.fieldOfStudy?.isNotEmpty ?? false ? ' · ${job.fieldOfStudy}' : ''}'),
                    if (job.requiresManagementExperience)
                      const _Bullet(text: 'Management experience required'),
                  ],
                ]))));
      }
      if (job.benefits.isNotEmpty) {
        detailCards.add(SizedBox(
            width: cardWidth,
            child: _Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _SectionTitle('Benefits'),
                  const SizedBox(height: 12),
                  for (final item in job.benefits) _Bullet(text: item),
                ]))));
      }
      if (job.companyOverview?.trim().isNotEmpty ?? false) {
        detailCards.add(SizedBox(
            width: cardWidth,
            child: _Card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const _SectionTitle('About the company'),
                  const SizedBox(height: 12),
                  Text(job.companyOverview!,
                      style: const TextStyle(
                          fontSize: 14, color: BrandColors.muted, height: 1.7)),
                ]))));
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 14 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0DE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.work_outline, color: BrandColors.orange),
                ),
                const SizedBox(width: 12),
                const Text('TalentBridge',
                    style: TextStyle(
                        color: BrandColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
              ]),
              const SizedBox(height: 18),
              _Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(job.title,
                        style: const TextStyle(
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.navy)),
                    const SizedBox(height: 8),
                    Text(job.companyName,
                        style: const TextStyle(
                            fontSize: 16,
                            color: BrandColors.muted,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, box) {
                      final facts = <(IconData, String, String)>[
                        (Icons.location_on_outlined, 'Location', job.location),
                        (
                          Icons.schedule_outlined,
                          'Employment',
                          job.employmentTypeLabel
                        ),
                        if (job.workplaceType != null)
                          (
                            Icons.laptop_mac_outlined,
                            'Work arrangement',
                            _workplace(job.workplaceType!)
                          ),
                        if (job.salaryRangeLabel != null)
                          (
                            Icons.payments_outlined,
                            'Compensation',
                            job.salaryRangeLabel!
                          ),
                        if (job.industry?.isNotEmpty ?? false)
                          (Icons.domain_outlined, 'Industry', job.industry!),
                      ];
                      final count = box.maxWidth >= 760
                          ? 3
                          : box.maxWidth >= 430
                              ? 2
                              : 1;
                      final width = (box.maxWidth - (count - 1) * 10) / count;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final fact in facts)
                          SizedBox(
                              width: width,
                              child: _PublicFactTile(
                                  icon: fact.$1,
                                  label: fact.$2,
                                  value: fact.$3)),
                      ]);
                    }),
                  ])),
              const SizedBox(height: 16),
              _Card(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const _SectionTitle('About the role'),
                    const SizedBox(height: 12),
                    Text(
                        job.description.isEmpty
                            ? 'No description provided.'
                            : job.description,
                        style: const TextStyle(
                            fontSize: 14,
                            color: BrandColors.muted,
                            height: 1.7)),
                  ])),
              if (detailCards.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 14, runSpacing: 14, children: detailCards),
              ],
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                  label: Text(applyLabel),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  static String _workplace(String value) => switch (value) {
        'remote' => 'Remote',
        'hybrid' => 'Hybrid',
        'on_site' => 'On-site',
        _ => value,
      };
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrandColors.border),
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: BrandColors.navy));
}

class _PublicFactTile extends StatelessWidget {
  const _PublicFactTile(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: BrandColors.orange),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w800,
                          color: BrandColors.muted)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy)),
                ]),
          ),
        ]),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  ',
              style: TextStyle(color: BrandColors.orange, fontSize: 16)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: BrandColors.muted, fontSize: 13.5, height: 1.5))),
        ]),
      );
}
