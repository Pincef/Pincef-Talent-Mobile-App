import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/jobs/application/application_provider.dart';
import 'package:talentbridge/features/jobs/data/models/application_model.dart';

/// Candidate-facing list of applications. Data comes from the jobs feature's
/// [ApplicationsRepository], keeping application actions and application
/// history on the same API boundary.
class MyApplicationsScreen extends ConsumerStatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  ConsumerState<MyApplicationsScreen> createState() =>
      _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends ConsumerState<MyApplicationsScreen> {
  _ApplicationFilter _filter = _ApplicationFilter.active;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myApplicationsListProvider);
    final notifier = ref.read(myApplicationsListProvider.notifier);

    if (state.isLoading && state.applications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.applications.isEmpty) {
      return _ApplicationsError(
          message: state.error!, onRetry: notifier.refresh);
    }

    final items = state.applications;
    final filtered = items.where(_filter.includes).toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    final counts = {
      for (final filter in _ApplicationFilter.values)
        filter: items.where(filter.includes).length,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Applications',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: BrandColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            _ApplicationTabs(
              selected: _filter,
              counts: counts,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 24),
            if (filtered.isEmpty)
              _EmptyApplications(filter: _filter)
            else
              ...filtered.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ApplicationCard(
                    application: application,
                    onViewDetails: application.jobId.isEmpty
                        ? null
                        : () => context.push('/jobs/${application.jobId}'),
                  ),
                ),
              ),
            if (state.error != null) ...[
              const SizedBox(height: 4),
              Text(state.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 11)),
            ],
            if (state.hasMore) ...[
              const SizedBox(height: 4),
              _LoadMoreApplications(
                isLoading: state.isLoadingMore,
                onTap: notifier.loadMore,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ApplicationFilter { active, interviewing, offers, archived }

extension on _ApplicationFilter {
  String get label => switch (this) {
        _ApplicationFilter.active => 'Active',
        _ApplicationFilter.interviewing => 'Interviewing',
        _ApplicationFilter.offers => 'Offers',
        _ApplicationFilter.archived => 'Archived',
      };

  bool includes(ApplicationSummary application) => switch (this) {
        _ApplicationFilter.active =>
          application.status == ApplicationBackendStatus.submitted ||
              application.status == ApplicationBackendStatus.shortlisted,
        _ApplicationFilter.interviewing =>
          application.status == ApplicationBackendStatus.interviewing,
        _ApplicationFilter.offers =>
          application.status == ApplicationBackendStatus.offered,
        _ApplicationFilter.archived =>
          application.status == ApplicationBackendStatus.rejected ||
              application.status == ApplicationBackendStatus.hired,
      };
}

class _ApplicationTabs extends StatelessWidget {
  const _ApplicationTabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _ApplicationFilter selected;
  final Map<_ApplicationFilter, int> counts;
  final ValueChanged<_ApplicationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandColors.border)),
      ),
      child: Wrap(
        spacing: 24,
        children: _ApplicationFilter.values.map((filter) {
          final isSelected = filter == selected;
          return InkWell(
            onTap: () => onSelected(filter),
            child: Container(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? BrandColors.orange : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                '${filter.label} (${counts[filter] ?? 0})',
                style: TextStyle(
                  color: isSelected ? BrandColors.orange : BrandColors.muted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, this.onViewDetails});

  final ApplicationSummary application;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    final stage = _stageFor(application.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: BrandColors.iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.business_center_outlined,
                    color: BrandColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.jobTitle ?? 'Job application',
                      style: const TextStyle(
                        color: BrandColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [application.companyName, application.location]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join('  •  '),
                      style: const TextStyle(
                          color: BrandColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: application.status),
            ],
          ),
          const SizedBox(height: 22),
          _ProgressBar(stage: stage),
          const SizedBox(height: 18),
          const Divider(color: BrandColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 15, color: BrandColors.muted),
              const SizedBox(width: 5),
              Text(
                'Applied ${DateFormat('d MMM y').format(application.appliedAt)}',
                style:
                    const TextStyle(color: BrandColors.muted, fontSize: 11.5),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.orange,
                  side: const BorderSide(color: BrandColors.orange),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7)),
                ),
                child: const Text('View Details',
                    style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _stageFor(ApplicationBackendStatus status) => switch (status) {
        ApplicationBackendStatus.submitted => 1,
        ApplicationBackendStatus.shortlisted => 2,
        ApplicationBackendStatus.interviewing => 3,
        ApplicationBackendStatus.offered || ApplicationBackendStatus.hired => 4,
        ApplicationBackendStatus.rejected => 1,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ApplicationBackendStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ApplicationBackendStatus.interviewing => const Color(0xFFB45309),
      ApplicationBackendStatus.offered ||
      ApplicationBackendStatus.hired =>
        const Color(0xFF15803D),
      ApplicationBackendStatus.rejected => const Color(0xFFB91C1C),
      _ => BrandColors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(applicationStatusLabel(status),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String applicationStatusLabel(ApplicationBackendStatus value) => value.label;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.stage});
  final int stage;

  @override
  Widget build(BuildContext context) {
    const labels = ['Applied', 'Screening', 'Interview', 'Final'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
              labels.length,
              (index) => Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      color: index < stage
                          ? BrandColors.orange
                          : BrandColors.muted,
                      fontWeight:
                          index < stage ? FontWeight.w700 : FontWeight.w500,
                    ),
                  )),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: stage / labels.length,
            minHeight: 6,
            backgroundColor: const Color(0xFFE3E8FA),
            valueColor: const AlwaysStoppedAnimation(BrandColors.orange),
          ),
        ),
      ],
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications({required this.filter});
  final _ApplicationFilter filter;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.work_outline, color: BrandColors.muted, size: 30),
            const SizedBox(height: 10),
            Text('No ${filter.label.toLowerCase()} applications yet.',
                style: const TextStyle(
                    color: BrandColors.navy, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ApplicationsError extends StatelessWidget {
  const _ApplicationsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load your applications.'),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(color: BrandColors.muted, fontSize: 11)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _LoadMoreApplications extends StatelessWidget {
  const _LoadMoreApplications({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: BrandColors.border),
        ),
        child: isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Load more applications'),
      );
}
