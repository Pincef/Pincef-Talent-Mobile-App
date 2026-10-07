import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/job_management_widget.dart';
import '../../application/job_management_provider.dart';
// import '../../data/models/job_management_model.dart';

class JobManagementScreen extends ConsumerStatefulWidget {
  const JobManagementScreen({super.key});

  @override
  ConsumerState<JobManagementScreen> createState() =>
      _JobManagementScreenState();
}

class _JobManagementScreenState extends ConsumerState<JobManagementScreen> {
  // UI-only for now — matches the stubbed search/sort pattern elsewhere.
  // Wire these to actually refetch once the real endpoint supports
  // filtering/pagination server-side.
  JobPostingTab _tab = JobPostingTab.active;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobManagementProvider);

    return _Body(
      state: state,
      tab: _tab,
      onTabChanged: (tab) => setState(() => _tab = tab),
      onRetry: () => ref.read(jobManagementProvider.notifier).load(),
      onPostJob: () => context.go('/jobs/new'),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.state,
      required this.tab,
      required this.onTabChanged,
      required this.onRetry,
      required this.onPostJob});

  final JobManagementState state;
  final JobPostingTab tab;
  final ValueChanged<JobPostingTab> onTabChanged;
  final VoidCallback onRetry;
  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final summary = state.summary;
    if (summary == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : (constraints.maxWidth >= 760 ? 2 : 1);

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 2,
                            child: ActivePipelinesCard(
                                summary: summary.pipeline,
                                onPostJob: onPostJob),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: HiringEfficiencyCard(
                                efficiency: summary.efficiency),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        ActivePipelinesCard(
                            summary: summary.pipeline, onPostJob: onPostJob),
                        const SizedBox(height: 16),
                        HiringEfficiencyCard(efficiency: summary.efficiency),
                      ],
                    ),
              const SizedBox(height: 24),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                      const Text('Job Postings',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B2A4E))),
                      JobPostingsHeader(
                          activeTab: tab,
                          activeCount: summary.activeTabCount,
                          pendingCount: summary.pendingTabCount,
                          closedCount: summary.closedTabCount,
                          onTabChanged: onTabChanged),
                    ])),
                if (isWide)
                  TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      label: const Text('Sort by: Recently Added'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          textStyle: const TextStyle(fontSize: 11))),
              ]),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
                children: [
                  ...summary.postings.map((job) => JobPostingCard(job: job)),
                  PostNewJobCard(onTap: onPostJob),
                ],
              ),
              const SizedBox(height: 20),
              JobPostingsFooter(
                shownCount: summary.postings.length,
                totalCount: summary.totalActivePostingsCount,
                currentPage: summary.currentPage,
                totalPages: summary.totalPages,
                onPageChanged: (page) {
                  // TODO: wire once pagination actually refetches
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
