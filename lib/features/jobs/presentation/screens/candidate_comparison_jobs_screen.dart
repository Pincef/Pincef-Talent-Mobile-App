import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';

/// Select an active requisition before opening its backend-backed candidate
/// ranking. This has its own route so the regular Jobs screen stays intact.
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
    final jobs = (state.summary?.postings ?? const [])
        .where((job) => job.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Candidate Comparison',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const SizedBox(height: 6),
            const Text(
                'Choose an active job to compare its AI ranked candidates by match score, role fit explanation, experience, and relevant work history.',
                style: TextStyle(color: BrandColors.muted, height: 1.45)),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Filter by job title, department, or location',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: BrandColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: BrandColors.border)),
              ),
            ),
            const SizedBox(height: 18),
            if (state.isLoading && state.summary == null)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator()))
            else if (state.error != null && state.summary == null)
              Center(
                  child: Column(children: [
                Text(state.error!),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: () => ref
                        .read(jobManagementProvider.notifier)
                        .load(tab: JobPipelineStatus.active),
                    child: const Text('Retry'))
              ]))
            else if (jobs.isEmpty)
              const _EmptyComparisonJobs()
            else
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 850 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: jobs.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 184),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: BrandColors.border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () =>
                            context.go('/jobs/${job.id}/candidate-ranking'),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.work_outline,
                                      color: BrandColors.orange),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward,
                                      size: 18, color: BrandColors.navy)
                                ]),
                                const SizedBox(height: 14),
                                Text(job.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: BrandColors.navy)),
                                const SizedBox(height: 6),
                                Text(
                                    [job.industry, job.location]
                                        .where((s) => s.trim().isNotEmpty)
                                        .join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: BrandColors.muted)),
                                const Spacer(),
                                Row(children: [
                                  const Icon(Icons.people_outline,
                                      size: 16, color: BrandColors.muted),
                                  const SizedBox(width: 6),
                                  Text('${job.applicantCount ?? 0} applicants',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: BrandColors.muted)),
                                  const Spacer(),
                                  const Text('Compare candidates',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: BrandColors.orange))
                                ]),
                              ]),
                        ),
                      ),
                    );
                  },
                );
              }),
          ]),
        ),
      ),
    );
  }
}

class _EmptyComparisonJobs extends StatelessWidget {
  const _EmptyComparisonJobs();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BrandColors.border)),
        child: const Column(children: [
          Icon(Icons.work_off_outlined, size: 30, color: BrandColors.muted),
          SizedBox(height: 10),
          Text('No active jobs to compare',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: BrandColors.navy)),
          SizedBox(height: 4),
          Text('Publish a job to view its candidate comparison.',
              style: TextStyle(color: BrandColors.muted))
        ]),
      );
}
