import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/candidate_dashboard_provider.dart';
import '../../../core/widgets/candidate_dashboard_widgets.dart';
import 'widgets/cv_upload_modal.dart';

class CandidateDashboardScreen extends ConsumerWidget {
  const CandidateDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return _DashboardBody(
      state: state,
      onRetry: () => ref.read(dashboardProvider.notifier).load(),
      onUploadCv: () => showCandidateCvUploadModal(context, ref),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody(
      {required this.state, required this.onRetry, required this.onUploadCv});

  final CandidateDashboardState state;
  final VoidCallback onRetry;
  final VoidCallback onUploadCv;

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

    // LayoutBuilder measuring THIS body's own available width, matching
    // welcome_screen.dart / login_screen.dart / forgot_password_screen.dart's
    // responsive pattern. Previously this used the window-wide isDesktop()
    // check (from breakpoints.dart) for the card layout too — that measures
    // the FULL window/screen width, not the actual space left for this body
    // after AppShell's 260px sidebar is subtracted, which is what made the
    // 2-column layout feel wrong/cramped at in-between window widths.
    // AppShell itself still uses isDesktop() to decide sidebar-vs-bottom-nav
    // chrome, which is a reasonable separate (global) decision — this only
    // fixes how the CONTENT inside that chrome reflows.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        if (!isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileSummaryCard(
                  highlights: summary.careerHighlights,
                  strengths: summary.coreStrengths,
                  stacked: true,
                ),
                const SizedBox(height: 16),
                WorkExperienceCard(summary: summary.workExperience),
                const SizedBox(height: 16),
                ActiveApplicationsCard(
                    applications: summary.applications, onViewAll: () {}),
                const SizedBox(height: 16),
                RecentUploadsCard(
                    uploads: summary.recentUploads, onAdd: onUploadCv),
                const SizedBox(height: 16),
                TopJobMatchesCard(
                    matches: summary.jobMatches, onDiscoverMore: () {}),
                const SizedBox(height: 16),
                WorkspaceTipCard(tip: summary.workspaceTip),
                const SizedBox(height: 80), // room for FAB
              ],
            ),
          );
        }

        // Wide: main column (2/3) + right sidebar column (1/3), matching the Figma 3-column layout.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileSummaryCard(
                      highlights: summary.careerHighlights,
                      strengths: summary.coreStrengths,
                      stacked: false,
                    ),
                    const SizedBox(height: 20),
                    WorkExperienceCard(summary: summary.workExperience),
                    const SizedBox(height: 20),
                    ActiveApplicationsCard(
                        applications: summary.applications, onViewAll: () {}),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RecentUploadsCard(
                        uploads: summary.recentUploads, onAdd: onUploadCv),
                    const SizedBox(height: 20),
                    TopJobMatchesCard(
                        matches: summary.jobMatches, onDiscoverMore: () {}),
                    const SizedBox(height: 20),
                    WorkspaceTipCard(tip: summary.workspaceTip),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
