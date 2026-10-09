import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/recruiter_dashboard_widgets.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/recruiter_dashboard_provider.dart';

class RecruiterDashboardScreen extends ConsumerWidget {
  const RecruiterDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recruiterDashboardProvider);
    // watch (not read) so this screen rebuilds once the real user profile
    // lands — e.g. after /auth/me resolves during login, or after a
    // session-restore completes on app relaunch.
    final user = ref.watch(authProvider).user;

    return _RecruiterDashboardBody(
      state: state,
      firstName: user?.firstName ?? 'there',
      onRetry: () => ref.read(recruiterDashboardProvider.notifier).load(),
    );
  }
}

class _RecruiterDashboardBody extends ConsumerWidget {
  const _RecruiterDashboardBody({
    required this.state,
    required this.firstName,
    required this.onRetry,
  });

  final RecruiterDashboardState state;
  // Sourced from authProvider (single source of truth for identity),
  // not from the dashboard summary payload — that endpoint is only
  // responsible for stats (activeJobs, newApplicants, etc.), not who
  // the user is.
  final String firstName;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final quickActions = [
      QuickAction(
        label: 'Post Job',
        icon: Icons.post_add,
        onTap: () => context.push('/jobs/new'),
      ),
    ];

    // LayoutBuilder measuring THIS body's own available width (already
    // excludes the sidebar, since AppShell places body inside an Expanded)
    // rather than the candidate dashboard's old approach of reusing the
    // window-wide isDesktop() check for the card grid too — that's what
    // was making it feel non-responsive at in-between window widths.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $firstName',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2A4E)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Here's what's happening with your recruitment funnel today.",
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  if (isWide)
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: wire an actual date-range picker/menu
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 14),
                      label: const Text('This Week'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B2A4E),
                        side: const BorderSide(color: Color(0xFFE7E9EF)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Active Jobs',
                            value: '${summary.activeJobs}',
                            note: summary.activeJobsNote,
                            icon: Icons.work_outline,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            label: 'New Applicants',
                            value: '${summary.newApplicants}',
                            note: summary.newApplicantsNote,
                            icon: Icons.person_add_alt_1_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            label: 'Hired this Month',
                            value: '${summary.hiredThisMonth}',
                            note: summary.hiredThisMonthNote,
                            icon: Icons.emoji_events_outlined,
                            dark: true,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        StatCard(
                          label: 'Active Jobs',
                          value: '${summary.activeJobs}',
                          note: summary.activeJobsNote,
                          icon: Icons.work_outline,
                        ),
                        const SizedBox(height: 12),
                        StatCard(
                          label: 'New Applicants',
                          value: '${summary.newApplicants}',
                          note: summary.newApplicantsNote,
                          icon: Icons.person_add_alt_1_outlined,
                        ),
                        const SizedBox(height: 12),
                        StatCard(
                          label: 'Hired this Month',
                          value: '${summary.hiredThisMonth}',
                          note: summary.hiredThisMonthNote,
                          icon: Icons.emoji_events_outlined,
                          dark: true,
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: PriorityJobsCard(
                              jobs: summary.priorityJobs, onViewAll: () {}),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              QuickActionsCard(actions: quickActions),
                              const SizedBox(height: 16),
                              RecentActivityCard(
                                  items: summary.recentActivity,
                                  onViewLog: () {}),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        PriorityJobsCard(
                            jobs: summary.priorityJobs, onViewAll: () {}),
                        const SizedBox(height: 16),
                        QuickActionsCard(actions: quickActions),
                        const SizedBox(height: 16),
                        RecentActivityCard(
                            items: summary.recentActivity, onViewLog: () {}),
                      ],
                    ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
