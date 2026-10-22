import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand_color.dart';
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
                  : _PublicJobContent(job: job),
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
  const _PublicJobContent({required this.job});

  final JobDetail job;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_outline, color: BrandColors.orange),
          ),
          const SizedBox(width: 12),
          const Text('TalentBridge',
              style: TextStyle(
                  color: BrandColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
        ]),
        const SizedBox(height: 22),
        _Card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Wrap(spacing: 18, runSpacing: 10, children: [
            _Meta(icon: Icons.location_on_outlined, text: job.location),
            _Meta(icon: Icons.schedule_outlined, text: job.employmentTypeLabel),
            if (job.workplaceType != null)
              _Meta(
                  icon: Icons.laptop_mac_outlined,
                  text: _workplace(job.workplaceType!)),
            if (job.salaryRangeLabel != null)
              _Meta(icon: Icons.payments_outlined, text: job.salaryRangeLabel!),
          ]),
        ])),
        const SizedBox(height: 16),
        _Card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('About the role'),
          const SizedBox(height: 12),
          Text(
              job.description.isEmpty
                  ? 'No description provided.'
                  : job.description,
              style: const TextStyle(
                  fontSize: 14, color: BrandColors.muted, height: 1.7)),
          if (job.responsibilities.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Responsibilities'),
            const SizedBox(height: 10),
            for (final item in job.responsibilities) _Bullet(text: item),
          ],
          if (job.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Skills and requirements'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final skill in job.requiredSkills)
                Chip(
                  label: Text(skill),
                  backgroundColor: const Color(0xFFF3F5F8),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
            if (job.minYearsOfExperience != null) ...[
              const SizedBox(height: 8),
              _Bullet(text: '${job.minYearsOfExperience} experience'),
            ],
            if (job.educationLevelLabel != null)
              _Bullet(text: 'Education: ${job.educationLevelLabel}'),
          ],
          if (job.benefits.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Benefits'),
            const SizedBox(height: 10),
            for (final item in job.benefits) _Bullet(text: item),
          ],
          if (job.companyOverview?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 22),
            const _SectionTitle('About the company'),
            const SizedBox(height: 10),
            Text(job.companyOverview!,
                style: const TextStyle(
                    fontSize: 14, color: BrandColors.muted, height: 1.7)),
          ],
        ])),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => context.go('/signup'),
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
            label: const Text('Create an account to apply'),
          ),
        ),
      ]),
    );
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: BrandColors.muted),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(color: BrandColors.muted, fontSize: 13)),
      ]);
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
