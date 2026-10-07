/// lib/features/profile/presentation/screens/recruiter_profile_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/utils/breakpoints.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import '../../application/profile_provider.dart';
import '../../data/models/activity_item.dart';
import '../../data/models/recruiter_performance.dart';

/// This is the body content for the /profile route — AppShell (sidebar,
/// topbar, avatar) is already provided by AppShellRoute, so this widget is
/// just the two-column content from the mockup.
class RecruiterProfileScreen extends ConsumerWidget {
  const RecruiterProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    // Shouldn't happen — this route sits behind the auth redirect guard in
    // app_router.dart — but avoids a null crash if it's ever hit mid-logout.
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = isDesktop(context)
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _LeftColumn(user: user)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _RightColumn(user: user)),
              ],
            ),
          )
        : Column(
            children: [
              _LeftColumn(user: user),
              const SizedBox(height: 16),
              _RightColumn(user: user),
            ],
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileCard(user: user),
        const SizedBox(height: 16),
        const _RecentActivityCard(),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.peach,
            backgroundImage: user.profileImage != null
                ? NetworkImage(user.profileImage!.url)
                : null,
            child: user.profileImage == null
                ? const Icon(Icons.person, size: 32, color: AppColors.orange)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      // Deep-links to Settings > Account rather than
                      // opening its own edit form here — name/email/photo
                      // live there, and bio/location/competencies/
                      // certifications moved there too so there's one
                      // editing surface, not two.
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orange,
                        side: const BorderSide(color: AppColors.orange),
                      ),
                    ),
                  ],
                ),
                Text(
                  // `title` (e.g. "Senior Lead Recruiter") was deliberately
                  // left off the backend for now — falling back to a role
                  // label until that field is added.
                  user.role == UserRole.recruiter ? 'Recruiter' : 'Candidate',
                  style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                if (user.bio != null && user.bio!.isNotEmpty)
                  Text(user.bio!,
                      style: const TextStyle(
                          color: BrandColors.muted, fontSize: 12, height: 1.5)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _IconLabel(icon: Icons.email_outlined, label: user.email),
                    if (user.location != null && user.location!.isNotEmpty)
                      _IconLabel(
                          icon: Icons.location_on_outlined,
                          label: user.location!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: BrandColors.muted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: BrandColors.muted, fontSize: 12)),
      ],
    );
  }
}

class _RecentActivityCard extends ConsumerWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(recruiterActivityProvider);
    final loaded = activityState.valueOrNull;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (loaded?.nextCursor != null)
                TextButton(
                  onPressed: loaded!.isLoadingMore
                      ? null
                      : () => ref
                          .read(recruiterActivityProvider.notifier)
                          .loadMore(),
                  child: Text(
                    loaded.isLoadingMore ? 'Loading...' : 'View All History',
                    style:
                        const TextStyle(color: AppColors.orange, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          activityState.when(
            data: (data) => data.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No recent activity yet.',
                        style:
                            TextStyle(color: BrandColors.muted, fontSize: 12)),
                  )
                : Column(
                    children: data.items
                        .map((item) => _ActivityRow(item: item))
                        .toList(),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("Couldn't load activity.",
                  style: TextStyle(color: BrandColors.muted, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.bolt_outlined,
                size: 14, color: AppColors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.message, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 2),
                Text(item.relativeTime,
                    style: const TextStyle(
                        color: BrandColors.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RightColumn extends ConsumerWidget {
  const _RightColumn({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performance = ref.watch(recruiterPerformanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PerformanceCard(performance: performance),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Core Competencies',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              user.competencies.isEmpty
                  ? const Text('No competencies added yet.',
                      style: TextStyle(color: BrandColors.muted, fontSize: 12))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: user.competencies
                          .map((c) => Chip(
                                label: Text(c,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.surface,
                                side: BorderSide.none,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Certifications',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              user.certifications.isEmpty
                  ? const Text('No certifications added yet.',
                      style: TextStyle(color: BrandColors.muted, fontSize: 12))
                  : Column(
                      children: user.certifications
                          .map((cert) => _CertificationRow(cert: cert))
                          .toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.performance});
  final AsyncValue<RecruiterPerformance> performance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: BrandColors.navy, borderRadius: BorderRadius.circular(10)),
      child: performance.when(
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PERFORMANCE INDEX',
                style: TextStyle(
                    color: Colors.white70, fontSize: 10.5, letterSpacing: 0.5)),
            const SizedBox(height: 14),
            _PerformanceBar(
                label: 'Fill Rate',
                value: data.fillRate,
                valueLabel: '${data.fillRate}%'),
            const SizedBox(height: 10),
            _PerformanceBar(
              label: 'Avg. Time-to-Hire',
              value: null,
              valueLabel: '${data.avgTimeToHireDays} Days',
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatBlock(
                        value: '${data.activeJobs}', label: 'ACTIVE JOBS')),
                Expanded(
                    child: _StatBlock(
                        value: '${data.hiresMade}', label: 'HIRES MADE')),
              ],
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text("Couldn't load performance data.",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  const _PerformanceBar({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.color = AppColors.orange,
  });

  final String label;
  final int? value; // null = show the label only, no bar (e.g. time-to-hire)
  final String valueLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            Text(valueLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value! / 100,
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 9.5, letterSpacing: 0.3)),
      ],
    );
  }
}

class _CertificationRow extends StatelessWidget {
  const _CertificationRow({required this.cert});
  final Certification cert;

  @override
  Widget build(BuildContext context) {
    final expiryLabel = cert.validThru != null
        ? 'Valid thru ${_formatDate(cert.validThru!)}'
        : cert.issuedAt != null
            ? 'Issued ${_formatDate(cert.issuedAt!)}'
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.verified_outlined,
                size: 15, color: AppColors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (expiryLabel != null)
                  Text(expiryLabel,
                      style: const TextStyle(
                          color: BrandColors.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}
