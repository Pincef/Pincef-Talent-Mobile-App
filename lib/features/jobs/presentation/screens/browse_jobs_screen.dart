import 'package:flutter/material.dart';
import 'package:talentbridge/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../application/job_management_provider.dart';
import '../../data/models/job_management_model.dart';

/// Candidate-facing "Browse Jobs" screen. Mirrors JobManagementScreen's
/// shape (a ConsumerStatefulWidget wiring a provider to a stateless _Body)
/// but talks to browseJobsProvider / GET /jobs instead of the recruiter's
/// /jobs/mine.
class BrowseJobsScreen extends ConsumerStatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  ConsumerState<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends ConsumerState<BrowseJobsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browseJobsProvider);
    final notifier = ref.read(browseJobsProvider.notifier);

    return _Body(
      state: state,
      onFilterChanged: notifier.applyFilters,
      onToggleSaved: notifier.toggleSaved,
      onLoadMore: notifier.loadMore,
      onRetry: notifier.refresh,
      onApply: (jobId) => context.push('/jobs/$jobId'),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onFilterChanged,
    required this.onToggleSaved,
    required this.onLoadMore,
    required this.onRetry,
    required this.onApply,
  });

  final BrowseJobsState state;
  final ValueChanged<JobBrowseFilters> onFilterChanged;
  final ValueChanged<String> onToggleSaved;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.jobs.isEmpty) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final mainColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Browse Jobs',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.navy)),
            const SizedBox(height: 4),
            Text(
              state.total > 0
                  ? 'Discover ${state.total} open ${state.total == 1 ? 'opportunity' : 'opportunities'}.'
                  : 'Discover open opportunities.',
              style: const TextStyle(fontSize: 12.5, color: BrandColors.muted),
            ),
            const SizedBox(height: 16),
            _FilterChips(filters: state.filters, onChanged: onFilterChanged),
            const SizedBox(height: 16),
            if (state.jobs.isEmpty)
              const _EmptyState()
            else
              ...state.jobs.map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _JobListingCard(
                      job: job,
                      onToggleSaved: () => onToggleSaved(job.id),
                      onApply: () => onApply(job.id),
                    ),
                  )),
            const SizedBox(height: 8),
            if (state.hasMore)
              _LoadMoreButton(
                  isLoading: state.isLoadingMore, onTap: onLoadMore),
          ],
        );

        if (!isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: mainColumn,
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: mainColumn),
              const SizedBox(width: 20),
              const SizedBox(width: 280, child: _InsightsSidebar()),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: BrandColors.iconBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: const Center(
        child: Text(
          'No jobs match your current filters.',
          style: TextStyle(fontSize: 12.5, color: BrandColors.muted),
        ),
      ),
    );
  }
}

// ============================================================
// Filter chips
// ============================================================

/// Chips map directly to job.model.ts's employmentType enum rather than
/// the mockup's arbitrary categories (Remote/Design/Product) — there's no
/// workplaceType or category field persisted on Job yet (see
/// job_management_model.dart's JobDraft.workplaceType note), so chips for
/// those would either do nothing or silently misfilter. These four are
/// real, backed by job.dto.ts's listJobsQuerySchema.employmentType filter.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.filters, required this.onChanged});

  final JobBrowseFilters filters;
  final ValueChanged<JobBrowseFilters> onChanged;

  static const _options = <String, String?>{
    'All Jobs': null,
    'Full-time': 'full_time',
    'Part-time': 'part_time',
    'Contract': 'contract',
    'Internship': 'internship',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.entries.map((entry) {
        final selected = filters.employmentType == entry.value;
        return _Chip(
          label: entry.key,
          selected: selected,
          onTap: () => onChanged(entry.value == null
              ? filters.copyWith(clearEmploymentType: true)
              : filters.copyWith(employmentType: entry.value)),
        );
      }).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BrandColors.orange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? BrandColors.orange : BrandColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : BrandColors.navy,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Job card
// ============================================================

class _JobListingCard extends StatelessWidget {
  const _JobListingCard(
      {required this.job, required this.onToggleSaved, required this.onApply});

  final JobListing job;
  final VoidCallback onToggleSaved;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          onApply, // card body and the Apply button both open the detail screen
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BrandColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: BrandColors.iconBg,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.business_center_outlined,
                  size: 20, color: BrandColors.navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(job.title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: BrandColors.navy)),
                      ),
                      if (job.matchScore != null)
                        _MatchBadge(score: job.matchScore!),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${job.companyName} • ${job.location}',
                      style: const TextStyle(
                          fontSize: 11.5, color: BrandColors.muted)),
                  if (job.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(job.employmentTypeLabel),
                        for (final tag in job.tags.take(4)) _Tag(tag),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(job.salaryRangeLabel,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: BrandColors.navy)),
                      const Spacer(),
                      IconButton(
                        onPressed: onToggleSaved,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 18,
                          color: job.isSaved
                              ? BrandColors.orange
                              : BrandColors.muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Apply Now',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final good = score >= 90;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFE8F8EE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$score% Match',
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: good ? const Color(0xFF16A34A) : BrandColors.orange)),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: BrandColors.iconBg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: BrandColors.navy)),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BrandColors.border),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Load more opportunities',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.muted)),
        ),
      ),
    );
  }
}

// ============================================================
// Right sidebar
// ============================================================

/// All three cards here are intentionally light on content — none of the
/// underlying data exists in the backend yet (candidate-facing match
/// scoring, a newsletter endpoint, an activity feed). Rather than fabricate
/// numbers (a fake "top 5%" claim, invented activity entries), each shows
/// honest placeholder copy, matching how HiringEfficiency/avgMatchQuality
/// are handled on the recruiter side until their real endpoints exist.
class _InsightsSidebar extends StatelessWidget {
  const _InsightsSidebar();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _CareerMomentumCard(),
        SizedBox(height: 16),
        _JobMarketTrendsCard(),
        SizedBox(height: 16),
        _RecentActivityCard(),
      ],
    );
  }
}

class _CareerMomentumCard extends StatelessWidget {
  const _CareerMomentumCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: BrandColors.navy, borderRadius: BorderRadius.circular(14)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text('Career Momentum',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 10),
          Text(
            // TODO: once a candidate-facing matching endpoint exists,
            // replace this with a real match-rating summary instead of
            // generic copy.
            'Apply to jobs to start building your match insights here.',
            style:
                TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _JobMarketTrendsCard extends StatelessWidget {
  const _JobMarketTrendsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Market Trends',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy)),
          const SizedBox(height: 8),
          const Text('Get salary insights and hiring trends in your inbox.',
              style: TextStyle(fontSize: 11, color: BrandColors.muted)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: BrandColors.iconBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Your email',
                      style: TextStyle(fontSize: 11, color: BrandColors.muted)),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  // TODO: no newsletter-signup endpoint exists yet.
                  AppToast.info(context, 'Coming soon.');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: BrandColors.orange,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.arrow_forward,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BrandColors.border)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.navy)),
          SizedBox(height: 10),
          // TODO: no activity-feed endpoint exists yet — wire this up once
          // one does, rather than showing invented entries.
          Text('No recent activity yet.',
              style: TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        ],
      ),
    );
  }
}
