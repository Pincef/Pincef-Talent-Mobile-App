import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'package:talentbridge/features/admin/application/admin_provider.dart';
import 'package:talentbridge/features/candidate_dashboard/presentation/widgets/cv_upload_modal.dart';
import 'package:talentbridge/features/jobs/application/job_management_provider.dart';
import 'package:talentbridge/features/jobs/application/application_provider.dart'
    show myApplicationsListProvider;
import 'package:talentbridge/features/notifications/application/notifications_provider.dart'
    show notificationsProvider, unreadNotificationCountProvider;
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
  final path = Uri.parse(route).path;
  if (path == '/messages') {
    ref.invalidate(messageThreadsProvider);
    ref.invalidate(candidateContactsProvider);
  } else if (path == '/jobs') {
    ref.invalidate(jobManagementProvider);
  } else if (path == '/my-applications') {
    ref.invalidate(myApplicationsListProvider);
  } else if (path == '/admin/users') {
    ref.invalidate(adminUsersProvider);
  } else if (path == '/admin/subscriptions') {
    ref.invalidate(adminSubscriptionsProvider);
  } else if (path == '/admin/jobs') {
    ref.invalidate(adminJobsProvider);
  } else if (path == '/admin/tickets') {
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
class AppShellRoute extends ConsumerStatefulWidget {
  const AppShellRoute({super.key, required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  ConsumerState<AppShellRoute> createState() => _AppShellRouteState();
}

class _AppShellRouteState extends ConsumerState<AppShellRoute> {
  StreamSubscription<Map<String, dynamic>>? _messageAlertSubscription;
  String? _manualSelectionLocation;
  int? _manualTopIndex;
  int? _manualSubIndex;

  @override
  void initState() {
    super.initState();
    _messageAlertSubscription =
        ref.read(chatSocketProvider).onThreadUpdate.listen((event) {
      final unread = (event['unreadCount'] as num?)?.toInt() ?? 0;
      if (unread <= 0 || !mounted) return;
      // The API persists a messages-category notification for the recipient.
      // Refresh the badge and any open notification center as soon as the
      // chat event arrives instead of waiting for the 30-second poll.
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(notificationsProvider);
      final preview = event['lastMessagePreview']?.toString().trim() ?? '';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              preview.isEmpty
                  ? 'You received a new message.'
                  : 'New message · $preview',
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              if (!mounted) return;
              context.go('/messages');
            },
          ),
          duration: const Duration(seconds: 6),
        ));
    });
  }

  @override
  void dispose() {
    _messageAlertSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isRecruiter = user?.role == UserRole.recruiter;
    final isAdmin = user?.role == UserRole.admin;
    final isCandidate = !isRecruiter && !isAdmin;
    final navItems = isAdmin
        ? kAdminNavItems
        : isRecruiter
            ? kRecruiterNavItems
            : kCandidateNavItems;
    final location = widget.state.uri.toString();
    final manualSelection =
        _manualSelectionLocation == location && _manualTopIndex != null
            ? (_manualTopIndex!, _manualSubIndex)
            : null;
    final (topIndex, subIndex) =
        manualSelection ?? _resolveIndex(navItems, location);

    void navigate(String? route) {
      if (route == null) return; // no screen wired up for this item yet
      _invalidateDataFor(ref, route);
      context.go(route);
    }

    return AppShell(
      currentIndex: topIndex,
      currentSubIndex: subIndex,
      navItems: navItems,
      body: widget.child,
      onNavTap: (index) {
        _clearManualSelection();
        navigate(navItems[index].route);
      },
      onSubItemTap: (topLevelIndex, subIdx) {
        final tapped = navItems[topLevelIndex].children[subIdx];
        // Items without their own screen open the nearest existing parent
        // screen. Menu entries with a dedicated route go there directly.
        final destination = tapped.route ?? navItems[topLevelIndex].route;
        if (destination != null) {
          setState(() {
            _manualSelectionLocation = destination;
            _manualTopIndex = topLevelIndex;
            _manualSubIndex = subIdx;
          });
        }
        navigate(destination);
      },
      onNotifications: () {
        ref.invalidate(notificationsProvider);
        context.push('/notification');
      },
      onSupport: isAdmin ? null : () => context.go('/support'),
      // Only meaningful on the candidate Browse Jobs screen right now —
      // there's nothing else this shared top-bar search should drive
      // (recruiter screens have no equivalent provider wired to it yet).
      onSearch: (isCandidate && location == '/jobs')
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
      showSidebarUserCard: isCandidate,
      topBarUserName: isRecruiter || isAdmin
          ? (user != null ? '${user.firstName} ${user.lastName}' : 'User')
          : null,
      topBarUserRole: isRecruiter || isAdmin ? _roleLabel(user?.role) : null,
      userName: user?.firstName ?? 'User',
      userRole: isRecruiter || isAdmin
          ? _roleLabel(user?.role)
          : (user?.role == UserRole.candidate ? 'Candidate' : 'User'),
      userEmail: user?.email ?? '',
      userLocation: user?.location ?? user?.country ?? '',
      profileImageUrl: user?.profileImage?.url,
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

  void _clearManualSelection() {
    if (_manualTopIndex == null) return;
    setState(() {
      _manualSelectionLocation = null;
      _manualTopIndex = null;
      _manualSubIndex = null;
    });
  }

  /// Matches the current location against navItems (and their children) to
  /// find which sidebar entry should be highlighted. Falls back to a
  /// longest-prefix match so e.g. a future /jobs/:id detail route still
  /// highlights "Jobs" even without an exact entry above.
  (int, int?) _resolveIndex(List<NavItem> navItems, String location) {
    final currentUri = Uri.parse(location);
    for (var i = 0; i < navItems.length; i++) {
      final item = navItems[i];
      for (var j = 0; j < item.children.length; j++) {
        final route = item.children[j].route;
        if (route != null &&
            (_routeMatches(Uri.parse(route), currentUri) ||
                currentUri.path.startsWith('${Uri.parse(route).path}/'))) {
          return (i, j);
        }
      }
      final route = item.route;
      if (route != null && _routeMatches(Uri.parse(route), currentUri)) {
        return (i, null);
      }
    }
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < navItems.length; i++) {
      final route = navItems[i].route;
      if (route != null &&
          currentUri.path.startsWith(route) &&
          route.length > bestLength) {
        bestIndex = i;
        bestLength = route.length;
      }
    }
    return (bestIndex, null);
  }

  bool _routeMatches(Uri menuRoute, Uri currentRoute) {
    if (menuRoute.path != currentRoute.path) return false;
    return menuRoute.queryParameters.entries.every(
      (entry) => currentRoute.queryParameters[entry.key] == entry.value,
    );
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
