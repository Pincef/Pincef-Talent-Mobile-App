import 'package:flutter/material.dart';
import '../theme/brand_color.dart';
import '../../features/recruiter_dashboard/data/model/recruiter_dashboard_models.dart';

// ============================================================
// Stat card (Active Jobs / New Applicants / Hired This Month)
// ============================================================

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    this.dark = false,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : BrandColors.navy;
    final mutedFg = dark ? Colors.white70 : BrandColors.muted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? BrandColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: dark ? null : Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: mutedFg)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.12) : BrandColors.iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: fg),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 4),
          Text(note, style: TextStyle(fontSize: 11, color: mutedFg)),
        ],
      ),
    );
  }
}

// ============================================================
// Priority Jobs
// ============================================================

class PriorityJobsCard extends StatelessWidget {
  const PriorityJobsCard({super.key, required this.jobs, required this.onViewAll});

  final List<PriorityJob> jobs;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Priority Jobs',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BrandColors.navy),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('View All', style: TextStyle(fontSize: 12, color: BrandColors.orange, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < jobs.length; i++) ...[
            if (i > 0) const Divider(color: BrandColors.border, height: 24),
            _PriorityJobRow(job: jobs[i]),
          ],
        ],
      ),
    );
  }
}

class _PriorityJobRow extends StatelessWidget {
  const _PriorityJobRow({required this.job});
  final PriorityJob job;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: BrandColors.iconBg, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.work_outline, size: 18, color: BrandColors.navy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: BrandColors.navy),
              ),
              const SizedBox(height: 2),
              Text(job.department, style: const TextStyle(fontSize: 11.5, color: BrandColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('APPLICANTS', style: TextStyle(fontSize: 8.5, color: BrandColors.muted, letterSpacing: 0.3)),
                Text('${job.applicantCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BrandColors.navy)),
              ],
            ),
            if (job.matchCount != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 13, color: BrandColors.orange),
                  const SizedBox(width: 2),
                  Text('${job.matchCount} Matches', style: const TextStyle(fontSize: 11, color: BrandColors.muted)),
                ],
              ),
            if (job.isScanning)
              const _StatusPill(label: 'Scanning...', background: BrandColors.orange, foreground: Colors.white),
            _StatusPill(
              label: job.status == JobPublishStatus.active ? 'ACTIVE' : 'DRAFTING',
              background: job.status == JobPublishStatus.active ? const Color(0xFF16A34A) : BrandColors.iconBg,
              foreground: job.status == JobPublishStatus.active ? Colors.white : BrandColors.muted,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.background, required this.foreground});
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: foreground)),
    );
  }
}

// ============================================================
// Quick Actions
// ============================================================

class QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const QuickAction(
      {required this.label, required this.icon, required this.onTap});
}

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key, required this.actions});
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BrandColors.navy)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: actions.length == 1 ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: actions.map((a) => _QuickActionTile(action: a)).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE8DB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 18, color: BrandColors.orange),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BrandColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Recent Activity
// ============================================================

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key, required this.items, required this.onViewLog});

  final List<RecentActivityItem> items;
  final VoidCallback onViewLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BrandColors.navy)),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _ActivityRow(item: items[i]),
          ],
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: onViewLog,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: const Text('View Activity Log', style: TextStyle(fontSize: 12, color: BrandColors.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final RecentActivityItem item;

  IconData get _icon => switch (item.type) {
        ActivityType.application => Icons.person_outline,
        ActivityType.interview => Icons.calendar_today_outlined,
        ActivityType.jobUpdate => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: BrandColors.iconBg, borderRadius: BorderRadius.circular(20)),
          child: Icon(_icon, size: 14, color: BrandColors.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: BrandColors.navy, height: 1.4),
                  children: [
                    if (item.prefixText.isNotEmpty) TextSpan(text: item.prefixText),
                    TextSpan(text: item.boldText, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (item.suffixText.isNotEmpty) TextSpan(text: item.suffixText),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(item.timeAgo, style: const TextStyle(fontSize: 10.5, color: BrandColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
