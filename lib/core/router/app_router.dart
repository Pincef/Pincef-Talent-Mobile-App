import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'package:talentbridge/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:talentbridge/features/candidate_dashboard/presentation/candidate_dashboard_screen.dart';
import 'package:talentbridge/features/onboarding/presentation/screens/candidate_profile_setup_screen.dart';
import 'package:talentbridge/features/onboarding/presentation/screens/profile_setup_complete_screen.dart';
import 'package:talentbridge/features/onboarding/presentation/screens/recruiter_profile_setup_screen.dart';
import 'package:talentbridge/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:talentbridge/features/recruiter_dashboard/presentation/screens/recruiter_dashboard_screen.dart';
import 'package:talentbridge/features/notifications/presentation/notification_center_screen.dart';
import 'package:talentbridge/features/hiring_pipeline/presentation/hiring_pipeline_screen.dart';
import 'package:talentbridge/features/interviews/presentation/interview_calendar_screen.dart';
import 'package:talentbridge/features/recruiter_dashboard/presentation/screens/recruitment_report_screen.dart';
import 'package:talentbridge/features/support/presentation/support_center_screen.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/shared/signup_screen.dart';
import '../../features/jobs/presentation/screens/job_management_screen.dart';
import '../../features/jobs/presentation/screens/post_job_screen.dart';
import '../../features/jobs/presentation/screens/browse_jobs_screen.dart';
import '../../features/jobs/presentation/screens/job_details_screen.dart';
import '../../features/jobs/presentation/screens/job_candidates_screen.dart';
import '../../features/jobs/presentation/screens/candidate_profile_preview_screen.dart';
import '../../features/jobs/data/models/application_model.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/profile/presentation/screens/recruiter_profile_screen.dart';
import '../../features/setting/presentation/screens/settings_screen.dart';
import '../../features/payments/presentation/screens/payment_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/candidate_messages_screen.dart';
import '../../features/admin/presentation/admin_console_screens.dart';
import '../widgets/app_shell_route.dart';

const _publicRoutes = {
  '/welcome',
  '/forgot-password',
  '/login',
  '/choose-role',
  '/signup',
};

/// These routes are valid immediately after registration. Keeping `/signup`
/// here prevents the auth-state refresh from redirecting to the dashboard
/// before SignUpScreen can navigate to the appropriate setup screen.
const _postSignupRoutes = {
  '/signup',
  '/recruiter-company-setup',
  '/candidate-profile-setup',
  '/profile-setup-complete',
};

UserRole _userRoleFromString(String value) {
  switch (value.toLowerCase()) {
    case 'recruiter':
      return UserRole.recruiter;
    case 'admin':
      return UserRole.admin;
    case 'candidate':
    default:
      return UserRole.candidate;
  }
}

bool _isRecruiter(AuthState authState) {
  return authState.user?.role == UserRole.recruiter;
}

bool _isAdmin(AuthState authState) => authState.user?.role == UserRole.admin;

/// Bridges a Riverpod StateNotifier's stream to something go_router's
/// `refreshListenable` understands, so GoRouter re-runs `redirect` whenever
/// auth state changes — WITHOUT rebuilding the GoRouter object itself.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// IMPORTANT: this Provider intentionally does NOT `ref.watch(authProvider)`
/// at the top level. Doing that was the actual bug — it recreated the
/// entire GoRouter (and every closure baked into its routes) on every auth
/// change, which raced against navigation calls like context.go('/dashboard')
/// that fire immediately after login/signup. The GoRouter below is built
/// ONCE. `redirect` and any role-dependent `builder` call ref.read(...)
/// fresh, every time they're actually invoked, so they can never be stale —
/// and `refreshListenable` tells GoRouter to re-run `redirect` on auth
/// changes without touching the router object itself.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable:
        GoRouterRefreshStream(ref.watch(authProvider.notifier).stream),
    redirect: (context, state) {
      final authState = ref.read(authProvider); // fresh every call, never stale
      final isLoggedIn = authState.isAuthenticated;
      final isPublicRoute = _publicRoutes.contains(state.matchedLocation);

      // The logout-success dialog intentionally remains over the current
      // workspace until its user chooses a destination.
      if (!isLoggedIn && !isPublicRoute && !authState.hasJustLoggedOut) {
        return '/login';
      }
      // New accounts are authenticated immediately after sign-up, but must
      // still be allowed through their role-specific setup. The setup screens
      // provide the explicit "Skip for now" path to /dashboard.
      if (isLoggedIn &&
          isPublicRoute &&
          !_postSignupRoutes.contains(state.matchedLocation)) {
        return '/dashboard';
      }

      final location = state.matchedLocation;
      if (isLoggedIn && location.startsWith('/admin') && !_isAdmin(authState)) {
        return '/dashboard';
      }
      if (isLoggedIn && _isAdmin(authState)) {
        if (location == '/dashboard') return '/admin';
        if (!location.startsWith('/admin') &&
            location != '/notification' &&
            location != '/support' &&
            location != '/settings') {
          return '/admin';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
          path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(
          path: '/choose-role',
          builder: (context, state) => const RoleSelectionScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(
          path: '/recruiter-company-setup',
          builder: (context, state) => const RecruiterProfileSetupScreen()),
      GoRoute(
        path: '/candidate-profile-setup',
        builder: (context, state) => const CandidateProfileSetupScreen(),
      ),
      GoRoute(
        path: '/profile-setup-complete',
        builder: (context, state) => const ProfileSetupCompleteScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShellRoute(state: state, child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminOverviewScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/jobs',
            builder: (context, state) => const AdminJobsScreen(),
          ),
          GoRoute(
            path: '/admin/tickets',
            builder: (context, state) => const AdminTicketsScreen(),
          ),
          GoRoute(
            path: '/admin/subscriptions',
            builder: (context, state) => const AdminSubscriptionsScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              final authState =
                  ref.read(authProvider); // fresh every call, never stale
              // print(
              //     'Role check in /dashboard builder: ${_isRecruiter(authState) ? 'recruiter' : 'candidate'}');
              return _isRecruiter(authState)
                  ? const RecruiterDashboardScreen()
                  : const CandidateDashboardScreen();
            },
          ),
          GoRoute(
            path: '/jobs',
            builder: (context, state) {
              final authState =
                  ref.read(authProvider); // fresh every call, never stale
              // kCandidateNavItems' "Browse Jobs" and kRecruiterNavItems'
              // "Jobs Management" both point at this same path (see
              // app_shell.dart) — split here the same way /dashboard does,
              // rather than adding a second route.
              return _isRecruiter(authState)
                  ? const JobManagementScreen()
                  : const BrowseJobsScreen();
            },
          ),
          GoRoute(
              path: '/jobs/new',
              builder: (context, state) => const PostJobScreen()),
          GoRoute(
            path: '/jobs/:jobId',
            builder: (context, state) =>
                JobDetailScreen(jobId: state.pathParameters['jobId']!),
          ),
          GoRoute(
            path: '/jobs/:jobId/candidates',
            builder: (context, state) =>
                JobCandidatesScreen(jobId: state.pathParameters['jobId']!),
            routes: [
              GoRoute(
                path: ':candidateId',
                builder: (context, state) => CandidateProfilePreviewScreen(
                  jobId: state.pathParameters['jobId']!,
                  candidateId: state.pathParameters['candidateId']!,
                  // Passed by job_candidates_screen.dart via `extra` — see
                  // that screen's onViewProfile. Null on a direct/deep
                  // link, which CandidateProfilePreviewScreen already
                  // handles gracefully.
                  applicant: state.extra as JobApplicantSummary?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const RecruiterProfileScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const RecruitmentReportScreen(),
          ),
          GoRoute(
            path: '/support',
            builder: (context, state) => const SupportCenterScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentScreen(),
          ),
          GoRoute(
            path: '/hiring-pipelines',
            builder: (context, state) => const HiringPipelineScreen(),
          ),
          GoRoute(
            path: '/interviews',
            builder: (context, state) => const InterviewCalendarScreen(),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => _isRecruiter(ref.read(authProvider))
                ? const MessagesScreen()
                : const CandidateMessagesScreen(),
          ),
        ],
      ),
      GoRoute(
          path: '/notification',
          builder: (context, state) => const NotificationCenterScreen())
      // TODO: add routes per feature as they're built:
      //   /candidate-profile   (CV upload, parsed profile view)
      //   /applications        (candidate's own applications)
      //   /recruiter/jobs      (post/manage jobs, mirrors GET /api/jobs/mine)
      //   /recruiter/company   (company setup — gate recruiter actions on this)
      //   /competency-tests    (create/manage tests)
      //   /assessments/:id     (candidate takes assessment; recruiter views results)
      //   /reports/:jobId      (recruitment report)
    ],
  );
});
