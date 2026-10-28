import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/application_provider.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/application_model.dart';
import '../../data/models/job_management_model.dart';

/// Recruiters choose a requisition first, then compare its real applicants.
class CandidateComparisonJobsScreen extends ConsumerStatefulWidget {
  const CandidateComparisonJobsScreen({super.key});

  @override
  ConsumerState<CandidateComparisonJobsScreen> createState() =>
      _CandidateComparisonJobsScreenState();
}

class _CandidateComparisonJobsScreenState
    extends ConsumerState<CandidateComparisonJobsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobManagementProvider);
    final allJobs = state.summary?.postings ?? const <JobPosting>[];
    final query = _query.trim().toLowerCase();
    final jobs = allJobs
        .where((job) =>
            job.title.toLowerCase().contains(query) ||
            job.industry.toLowerCase().contains(query) ||
            job.location.toLowerCase().contains(query) ||
            job.id.toLowerCase().contains(query))
        .toList();
    final applicants =
        allJobs.fold<int>(0, (sum, job) => sum + (job.applicantCount ?? 0));

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComparisonPageHeader(
                  wide: wide,
                  query: _query,
                  onQueryChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(builder: (context, box) {
                  final columns = box.maxWidth >= 760 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: columns == 1 ? 4.2 : 2.5,
                    children: [
                      _ComparisonStat(
                        icon: Icons.assignment_outlined,
                        label: 'Active requisitions',
                        value: '${state.summary?.activeTabCount ?? 0} roles',
                        note: 'Select a role to compare applicants',
                      ),
                      _ComparisonStat(
                        icon: Icons.people_alt_outlined,
                        label: 'Applicants',
                        value: '$applicants candidates',
                        note: 'Across active requisitions',
                      ),
                      const _ComparisonStat(
                        icon: Icons.fact_check_outlined,
                        label: 'Comparison basis',
                        value: 'Assessment',
                        note: 'Best graded result per candidate',
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                if (state.isLoading && state.summary == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.error != null && state.summary == null)
                  _LoadError(
                    message: state.error!,
                    onRetry: () => ref
                        .read(jobManagementProvider.notifier)
                        .load(tab: JobPipelineStatus.active),
                  )
                else if (jobs.isEmpty)
                  _EmptyComparisonJobs(hasQuery: query.isNotEmpty)
                else
                  LayoutBuilder(builder: (context, box) {
                    final columns = box.maxWidth >= 850 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: jobs.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 350,
                      ),
                      itemBuilder: (context, index) => _ComparisonJobCard(
                        job: jobs[index],
                        onCompare: () => context
                            .go('/candidate-comparison/${jobs[index].id}'),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ComparisonPageHeader extends StatelessWidget {
  const _ComparisonPageHeader({
    required this.wide,
    required this.query,
    required this.onQueryChanged,
  });

  final bool wide;
  final String query;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    const heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Job Role for Comparison',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy)),
        SizedBox(height: 6),
        Text(
          'Choose a job to rank its applicants by their best graded assessment result.',
          style: TextStyle(color: BrandColors.muted, height: 1.45),
        ),
      ],
    );
    final search = SizedBox(
      width: wide ? 340 : double.infinity,
      child: TextField(
        onChanged: onQueryChanged,
        decoration: InputDecoration(
          hintText: 'Filter by role, requisition ID, or department',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BrandColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BrandColors.border)),
        ),
      ),
    );
    if (!wide) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, const SizedBox(height: 16), search]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Expanded(child: heading),
      const SizedBox(width: 20),
      search,
    ]);
  }
}

class _ComparisonStat extends StatelessWidget {
  const _ComparisonStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: BrandColors.navy.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: BrandColors.navy, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 11)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BrandColors.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 10)),
              ],
            ),
          ),
        ]),
      );
}

class _ComparisonJobCard extends ConsumerWidget {
  const _ComparisonJobCard({required this.job, required this.onCompare});

  final JobPosting job;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicantState = ref.watch(jobApplicantsProvider(job.id));
    final applicants = [...applicantState.applications]..sort((a, b) {
        final aShortlisted =
            a.status == ApplicationBackendStatus.shortlisted ? 1 : 0;
        final bShortlisted =
            b.status == ApplicationBackendStatus.shortlisted ? 1 : 0;
        if (aShortlisted != bShortlisted) {
          return bShortlisted.compareTo(aShortlisted);
        }
        return a.appliedAt.compareTo(b.appliedAt);
      });
    final shortlistCount = applicantState.applications
        .where((a) => a.status == ApplicationBackendStatus.shortlisted)
        .length;
    final ready = applicantState.total >= 3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _StatusPill(
            label: ready ? 'APPLICANTS AVAILABLE' : 'BUILDING APPLICANT POOL',
            ready: ready,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                job.id.length > 7
                    ? job.id.substring(job.id.length - 7).toUpperCase()
                    : job.id.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    color: BrandColors.muted,
                    fontWeight: FontWeight.w700)),
          ),
          const Icon(Icons.fact_check_outlined,
              size: 19, color: BrandColors.orange),
        ]),
        const SizedBox(height: 13),
        Text(job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 19,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy)),
        const SizedBox(height: 8),
        Text(
          [job.industry, job.location, job.workMode]
              .where((value) => value.trim().isNotEmpty && value != '—')
              .join('  •  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: BrandColors.muted),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(9)),
          child: applicantState.isLoading && applicants.isEmpty
              ? const Row(children: [
                  SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 9),
                  Text('Loading applicants…',
                      style: TextStyle(fontSize: 11, color: BrandColors.muted)),
                ])
              : applicantState.error != null && applicants.isEmpty
                  ? const Text('Applicant details are unavailable right now.',
                      style: TextStyle(fontSize: 11, color: BrandColors.muted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                                shortlistCount > 0
                                    ? 'Shortlisted Candidates ($shortlistCount)'
                                    : '${applicantState.total} Applicants',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: BrandColors.navy)),
                          ),
                          Text(
                              applicantState.total == 0
                                  ? 'No applicants yet'
                                  : '$shortlistCount shortlisted',
                              style: const TextStyle(
                                  fontSize: 10, color: BrandColors.muted)),
                        ]),
                        if (applicants.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text('New applications will appear here.',
                              style: TextStyle(
                                  fontSize: 11, color: BrandColors.muted)),
                        ] else ...[
                          const SizedBox(height: 9),
                          for (final applicant in applicants.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(children: [
                                _CandidateAvatar(applicant: applicant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(applicant.candidate.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: BrandColors.navy)),
                                ),
                                Text(
                                  applicant.status.label,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: BrandColors.muted),
                                ),
                              ]),
                            ),
                        ],
                      ],
                    ),
        ),
        const Spacer(),
        Row(children: [
          Expanded(
            child: Text(
              applicantState.total < 3
                  ? 'Assessment scores appear after candidates are graded'
                  : 'Compare candidates by their best assessment score',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: BrandColors.muted),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: applicantState.total == 0 ? null : onCompare,
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('Compare'),
            style: FilledButton.styleFrom(
              backgroundColor: BrandColors.navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _CandidateAvatar extends StatelessWidget {
  const _CandidateAvatar({required this.applicant});
  final JobApplicantSummary applicant;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 13,
        backgroundColor: BrandColors.navy.withValues(alpha: .1),
        backgroundImage: applicant.candidate.profileImageUrl == null
            ? null
            : NetworkImage(applicant.candidate.profileImageUrl!),
        child: applicant.candidate.profileImageUrl == null
            ? Text(applicant.candidate.initials,
                style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy))
            : null,
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.ready});
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: ready ? const Color(0xFFFFE6DA) : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: ready ? const Color(0xFF8C3A14) : BrandColors.muted)),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

class _EmptyComparisonJobs extends StatelessWidget {
  const _EmptyComparisonJobs({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BrandColors.border)),
        child: Column(children: [
          const Icon(Icons.work_off_outlined,
              size: 30, color: BrandColors.muted),
          const SizedBox(height: 10),
          Text(
              hasQuery
                  ? 'No matching requisitions'
                  : 'No active jobs to compare',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: BrandColors.navy)),
          const SizedBox(height: 4),
          Text(
            hasQuery
                ? 'Try another role, department, location, or requisition ID.'
                : 'Publish a job and receive applications to start comparing candidates.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.muted),
          ),
        ]),
      );
}
