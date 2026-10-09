import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'package:talentbridge/features/admin/application/admin_provider.dart';
import 'package:talentbridge/features/candidate_dashboard/presentation/widgets/cv_upload_modal.dart';
import 'package:talentbridge/features/jobs/application/job_management_provider.dart';
import 'package:talentbridge/features/messages/application/messages_provider.dart'
    show messageThreadsProvider;
import 'package:talentbridge/features/messages/application/candidate_messages_provider.dart'
    show candidateContactsProvider;
import 'package:talentbridge/core/realtime/socket_service.dart'
    show chatSocketProvider;
import 'app_shell.dart';
import 'logout_success_dialog.dart';

/// Called on every nav tap (top-level and sub-item, both funnel through
/// `navigate` above) — refetches whatever data backs the destination
/// screen, regardless of whether go_router happens to dispose the
/// previous screen's widget tree on this navigation or keeps it alive in
/// the background. Relying on autoDispose's widget-lifecycle timing here
/// would only be correct in the "disposes" case; this makes it correct
/// either way, since it's driven by the tap itself, not by disposal.
///
/// Extend this as more screens need "always fresh on nav" behavior — one
/// `ref.invalidate(...)` per route/provider pair. Harmless to invalidate a
/// provider that isn't currently being watched (e.g. invalidating the
/// candidate inbox while looking at the recruiter one) — Riverpod just
/// marks it for recompute next time something reads it.
void _invalidateDataFor(WidgetRef ref, String route) {
  if (route == '/messages') {
    ref.invalidate(messageThreadsProvider);
    ref.invalidate(candidateContactsProvider);
  } else if (route == '/jobs') {
    ref.invalidate(jobManagementProvider);
  } else if (route == '/admin/users') {
    ref.invalidate(adminUsersProvider);
  } else if (route == '/admin/subscriptions') {
    ref.invalidate(adminSubscriptionsProvider);
  } else if (route == '/admin/jobs') {
    ref.invalidate(adminJobsProvider);
  } else if (route == '/admin/tickets') {
    ref.invalidate(adminTicketsProvider);
  }
}

/// Hosts the persistent AppShell chrome for every route nested under the
/// ShellRoute in app_router.dart. This replaces what used to be copy-pasted
/// into every screen (currentIndex/currentSubIndex, the onNavTap switch,
/// user info, logout) — see candidate_dashboard_screen.dart,
/// recruiter_dashboard_screen.dart, job_management_screen.dart and
/// post_job_screen.dart's git history for the per-screen wiring this
/// replaces.
///
/// Recruiter vs candidate is decided here, once, from authProvider — the
/// same _isRecruiter-style check app_router.dart already uses for the
/// /dashboard route.
class AppShellRoute extends ConsumerWidget {
  const AppShellRoute({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isRecruiter = user?.role == UserRole.recruiter;
    final isAdmin = user?.role == UserRole.admin;
    final isCandidate = !isRecruiter && !isAdmin;
    final navItems = isAdmin
        ? kAdminNavItems
        : isRecruiter
            ? kRecruiterNavItems
            : kCandidateNavItems;
    final (topIndex, subIndex) = _resolveIndex(navItems, state.matchedLocation);

    void navigate(String? route) {
      if (route == null) return; // no screen wired up for this item yet
      _invalidateDataFor(ref, route);
      context.go(route);
    }

    return AppShell(
      currentIndex: topIndex,
      currentSubIndex: subIndex,
      navItems: navItems,
      body: child,
      onNavTap: (index) => navigate(navItems[index].route),
      onSubItemTap: (topLevelIndex, subIdx) {
        final tapped = navItems[topLevelIndex].children[subIdx];
        // No dedicated route yet for this child (e.g. "Competense base
        // assessment") -> fall back to the parent's route, same as the
        // manual /jobs fallback job_management_screen and post_job_screen
        // had before this was centralized.
        navigate(tapped.route ?? navItems[topLevelIndex].route);
      },
      onNotifications: () => context.push('/notification'),
      onSupport: isAdmin ? null : () => context.go('/support'),
      // Only meaningful on the candidate Browse Jobs screen right now —
      // there's nothing else this shared top-bar search should drive
      // (recruiter screens have no equivalent provider wired to it yet).
      onSearch: (isCandidate && state.matchedLocation == '/jobs')
          ? (query) =>
              ref.read(browseJobsProvider.notifier).setSearchText(query)
          : null,
      onLogout: () async {
        await ref.read(authProvider.notifier).logout();
        // Belt-and-suspenders alongside the autoDispose fix on the
        // messaging providers: if this app's route shell keeps Messages
        // (or Candidates) mounted in the background rather than fully
        // disposing it on navigation, autoDispose alone won't fire here.
        // Explicitly invalidating on logout guarantees the next login
        // never sees the previous session's cached inbox/thread data.
        ref.invalidate(messageThreadsProvider);
        ref.invalidate(candidateContactsProvider);
        ref.invalidate(chatSocketProvider);
        if (!context.mounted) return;
        showLogoutSuccessDialog(
          context,
          onSignInAgain: () => context.go('/login'),
          onReturnHome: () => context.go('/welcome'),
        );
      },

      // --- Everything below differs by role ---
      // Candidate mockup shows the sidebar user card (name/role/email/
      // location) with no topbar name; recruiter mockup is the opposite.
      // The candidate values here are the same placeholder mock data
      // candidate_dashboard_screen.dart used to hardcode — UserModel
      // doesn't carry a job title/location field yet, so there's nothing
      // real to source them from until that lands.
      showSidebarUserCard: isCandidate,
      topBarUserName: isRecruiter || isAdmin
          ? (user != null ? '${user.firstName} ${user.lastName}' : 'User')
          : null,
      topBarUserRole: isRecruiter || isAdmin ? _roleLabel(user?.role) : null,
      userName:
          isRecruiter || isAdmin ? (user?.firstName ?? 'User') : 'ALEX RIVERA',
      userRole: isRecruiter || isAdmin
          ? _roleLabel(user?.role)
          : 'Senior UI/UX Designer',
      userEmail: isRecruiter || isAdmin
          ? (user?.email ?? '')
          : 'alex.rivera@design.io',
      userLocation: isRecruiter || isAdmin ? '' : 'San Francisco, CA',
      primaryActionLabel: isAdmin
          ? 'Admin Overview'
          : isRecruiter
              ? 'Post New Job'
              : 'Upload CV',
      primaryActionIcon: Icons.add,
      onUploadCv: isAdmin
          ? () => context.go('/admin')
          : isRecruiter
              ? () => context.push('/jobs/new')
              : () => showCandidateCvUploadModal(context, ref),
    );
  }

  /// Matches the current location against navItems (and their children) to
  /// find which sidebar entry should be highlighted. Falls back to a
  /// longest-prefix match so e.g. a future /jobs/:id detail route still
  /// highlights "Jobs" even without an exact entry above.
  (int, int?) _resolveIndex(List<NavItem> navItems, String location) {
    for (var i = 0; i < navItems.length; i++) {
      final item = navItems[i];
      for (var j = 0; j < item.children.length; j++) {
        if (item.children[j].route == location) return (i, j);
      }
      if (item.route == location) return (i, null);
    }
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < navItems.length; i++) {
      final route = navItems[i].route;
      if (route != null &&
          location.startsWith(route) &&
          route.length > bestLength) {
        bestIndex = i;
        bestLength = route.length;
      }
    }
    return (bestIndex, null);
  }

  /// UserRole is an enum (e.g. UserRole.recruiter) — this maps it to a
  /// display label. Falls back to a sensible default while the profile
  /// hasn't loaded yet, instead of showing something like "null" or the
  /// enum's raw name.
  String _roleLabel(UserRole? role) {
    if (role == null) return 'Recruiter';
    switch (role) {
      case UserRole.recruiter:
        return 'Lead Recruiter';
      case UserRole.candidate:
        return 'Candidate';
      case UserRole.admin:
        return 'System Administrator';
    }
  }
}
