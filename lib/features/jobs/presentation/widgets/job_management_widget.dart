import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/brand_color.dart';
import '../../data/models/job_management_model.dart';

// ============================================================
// Active Job Pipelines (dark, left panel)
// ============================================================

class ActivePipelinesCard extends StatelessWidget {
  const ActivePipelinesCard(
      {super.key, required this.summary, required this.onPostJob});

  final PipelineSummary summary;
  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: BrandColors.navy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Active Job Pipelines',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Manage your active talent acquisition flows. You currently have '
            '${summary.openRoles} open roles with high engagement levels across ${summary.regionsCount} regions.',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PipelineStatBlock(
                  label: 'TOTAL APPLICANTS',
                  value: _formatThousands(summary.totalApplicants)),
              _PipelineStatBlock(
                  label: 'AVG MATCH QUALITY',
                  value: '${summary.avgMatchQuality}%'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onPostJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Post Your Job',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

String _formatThousands(int value) {
  final str = value.toString();
  if (str.length <= 3) return str;
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
    buffer.write(str[i]);
  }
  return buffer.toString();
}

class _PipelineStatBlock extends StatelessWidget {
  const _PipelineStatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 9.5, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ============================================================
// Hiring Efficiency (white, right panel)
// ============================================================

class HiringEfficiencyCard extends StatelessWidget {
  const HiringEfficiencyCard({super.key, required this.efficiency});
  final HiringEfficiency efficiency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hiring Efficiency',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '+${efficiency.growthPercent}% Growth',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Icon(Icons.trending_up, size: 25, color: BrandColors.orange),
          const SizedBox(height: 12),
          Text(
            'Your time-to-fill for technical roles has decreased by '
            '${efficiency.timeToFillDeltaDays} days this month. Keep up the momentum!',
            style: const TextStyle(
                fontSize: 12, color: BrandColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 22,
                child: Stack(
                  children: List.generate(3, (i) {
                    return Positioned(
                      left: i * 16.0,
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                            radius: 9,
                            backgroundColor: BrandColors.iconBg,
                            child: Icon(Icons.person,
                                size: 11, color: BrandColors.navy)),
                      ),
                    );
                  }),
                ),
              ),
              Text('+${efficiency.recentHiresCount} Recent Hires',
                  style:
                      const TextStyle(fontSize: 11, color: BrandColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Job Postings — filter tabs + sort
// ============================================================

enum JobPostingTab { active, pending, closed }

class JobPostingsHeader extends StatelessWidget {
  const JobPostingsHeader({
    super.key,
    required this.activeTab,
    required this.activeCount,
    required this.pendingCount,
    required this.closedCount,
    required this.onTabChanged,
  });

  final JobPostingTab activeTab;
  final int activeCount;
  final int pendingCount;
  final int closedCount;
  final ValueChanged<JobPostingTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _TabChip(
            label: 'ACTIVE ($activeCount)',
            selected: activeTab == JobPostingTab.active,
            onTap: () => onTabChanged(JobPostingTab.active)),
        _TabChip(
            label: 'PENDING ($pendingCount)',
            selected: activeTab == JobPostingTab.pending,
            onTap: () => onTabChanged(JobPostingTab.pending)),
        _TabChip(
            label: 'CLOSED ($closedCount)',
            selected: activeTab == JobPostingTab.closed,
            onTap: () => onTabChanged(JobPostingTab.closed)),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: selected ? const Color(0xFFD8E3F7) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected ? BrandColors.navy : BrandColors.muted,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Job posting grid card
// ============================================================

class JobPostingCard extends StatelessWidget {
  const JobPostingCard({super.key, required this.job});
  final JobPosting job;

  // Status pill now only reflects the three real backend states
  // (active/drafting/closed). `isScanning` used to masquerade as a fourth
  // status value here — it isn't one, so it's rendered as a separate small
  // badge below instead, only ever alongside `active`.
  (Color, Color, String) get _statusStyle => switch (job.status) {
        JobPipelineStatus.active => (
            const Color(0xFF16A34A),
            Colors.white,
            'ACTIVE'
          ),
        JobPipelineStatus.drafting => (
            BrandColors.iconBg,
            BrandColors.muted,
            'DRAFTING'
          ),
        JobPipelineStatus.closed => (
            const Color(0xFFE7E9EF),
            BrandColors.muted,
            'CLOSED'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _statusStyle;

    return InkWell(
      onTap: () => context.push('/jobs/${job.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0CDBD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: BrandColors.iconBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.work_outline,
                      size: 17, color: BrandColors.navy),
                ),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (job.status == JobPipelineStatus.active &&
                        job.isScanning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: BrandColors.orange,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('SCANNING',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: fg)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(job.title,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: BrandColors.navy)),
            const SizedBox(height: 2),
            Text(
              '${job.location} • ${job.department} • ${job.workMode}',
              style: const TextStyle(fontSize: 11, color: BrandColors.muted),
            ),
            const Spacer(),
            const Divider(height: 20, color: Color(0xFFF0E1DA)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('APPLICANTS',
                        style: TextStyle(
                            fontSize: 8.5,
                            color: BrandColors.muted,
                            letterSpacing: 0.3)),
                    Text(
                      job.applicantCount?.toString() ?? '–',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.navy),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('MATCH QUALITY',
                        style: TextStyle(
                            fontSize: 8.5,
                            color: BrandColors.muted,
                            letterSpacing: 0.3)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 30,
                          height: 4,
                          decoration: BoxDecoration(
                              color: job.matchQuality == null
                                  ? const Color(0xFFE7E9EF)
                                  : job.matchQuality! >= 90
                                      ? const Color(0xFF16A34A)
                                      : BrandColors.orange,
                              borderRadius: BorderRadius.circular(8))),
                      const SizedBox(width: 5),
                      Text(
                          job.matchQuality != null
                              ? '${job.matchQuality}%'
                              : 'N/A',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: job.matchQuality == null
                                  ? BrandColors.muted
                                  : job.matchQuality! >= 90
                                      ? const Color(0xFF16A34A)
                                      : BrandColors.orange))
                    ]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PostNewJobCard extends StatelessWidget {
  const PostNewJobCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: BrandColors.border, style: BorderStyle.solid),
          color: BrandColors.iconBg.withValues(alpha: 0.4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: BrandColors.orange),
              ),
              const SizedBox(height: 10),
              const Text('Post New Job',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: BrandColors.navy)),
              const SizedBox(height: 4),
              const Text(
                'Start a new hiring cycle and find your next top talent.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: BrandColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Pagination footer
// ============================================================

class JobPostingsFooter extends StatelessWidget {
  const JobPostingsFooter({
    super.key,
    required this.shownCount,
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int shownCount;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: [
        Text('Showing $shownCount of $totalCount active postings',
            style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed:
                  currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              visualDensity: VisualDensity.compact,
            ),
            for (var page = 1; page <= totalPages; page++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onPageChanged(page),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: page == currentPage
                          ? BrandColors.orange
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$page',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: page == currentPage
                            ? Colors.white
                            : BrandColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}
