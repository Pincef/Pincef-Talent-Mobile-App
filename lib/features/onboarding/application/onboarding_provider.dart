import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/models/user_model.dart';
import '../presentation/screens/verify_email_screen.dart';
import '../presentation/screens/role_selection_screen.dart';
import '../presentation/screens/recruiter_profile_setup_screen.dart';
import '../presentation/screens/candidate_profile_setup_screen.dart';
import '../presentation/screens/profile_setup_complete_screen.dart';

// ---------------------------------------------------------------------------
// Onboarding state — tracks where the user is in the post-verification flow.
// ---------------------------------------------------------------------------
enum OnboardingStep {
  /// User just verified email and needs to pick a role (recruiter / candidate).
  selectRole,

  /// User is filling out their company/profile details.
  profileSetup,

  /// Onboarding is complete; the user is routed to their dashboard.
  complete,
}

/// Notifier that tracks the onboarding step and the selected role.
/// Consumed by the GoRouter redirect and the onboarding scaffold.
final onboardingStepProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingStep>((ref) =>
        OnboardingStep.selectRole);

final selectedRoleProvider =
    StateProvider<UserRole?>((ref) => null); // already exists

/// ---------------------------------------------------------------------
// Onboarding notifier — decides navigation based on step + role.
// ---------------------------------------------------------------------
class OnboardingNotifier extends StateNotifier<OnboardingStep> {
  OnboardingNotifier() : super(OnboardingStep.selectRole);

  /// Called when the user finishes email verification.
  /// Routes them based on whether a role has already been selected.
  void onEmailVerified(UserRole? role, UserModel user) {
    // If they already picked a role during a previous session, skip to
    // the profile setup for that role.
    if (role != null) {
      state = _stepForRole(role);
      return;
    }

    // No role yet — show the role selection screen.
    state = OnboardingStep.selectRole;
  }

  /// Maps a role to the appropriate onboarding step.
  OnboardingStep _stepForRole(UserRole role) {
    switch (role) {
      case UserRole.recruiter:
        return OnboardingStep.profileSetup;
      case UserRole.candidate:
        return OnboardingStep.profileSetup;
      case UserRole.admin:
        return OnboardingStep.complete;
      default:
        return OnboardingStep.selectRole;
    }
  }

  /// Move to the next step. The caller (GoRouter/scaffold) decides the
  // actual screen based on the new step + role.
  void nextStep(UserRole? role) {
    if (role != null) {
      state = _stepForRole(role);
    } else {
      // No role selected yet — stay at role selection.
      state = OnboardingStep.selectRole;
    }
  }

  /// Mark onboarding as complete and route to dashboard.
  void finish() {
    state = OnboardingStep.complete;
  }
}

// ---------------------------------------------------------------------------
// Router transitions — decide where to go based on auth + onboarding state.
// ---------------------------------------------------------------------------
//
// These live in GoRouter(redirect: [...]) or are used by the root
// scaffold/widget that watches both auth and onboarding state.

/// First check: is the user verifying email?
String? verifyEmailRedirect(BuildContext context, GoRouteState state) {
  final auth = ref.watch(authProvider);
  if (auth.isVerifyingEmail) return '/verify-email';
  return null;
}

/// Then check onboarding state.
String? onboardingRedirect(BuildContext context, GoRouteState state) {
  final onboarding = ref.watch(onboardingStepProvider);
  final role = ref.watch(selectedRoleProvider);
  final auth = ref.watch(authProvider);

  // If email not verified, go to verification screen.
  if (auth.isVerifyingEmail) return '/verify-email';

  // No stored auth → welcome (new visitors).
  if (!auth.isAuthenticated) return '/welcome';

  // Decide destination based on step + role.
  switch (onboarding) {
    case OnboardingStep.selectRole:
      // If role already picked (from a previous session), jump to profile.
      if (role != null) return '/profile-setup';
      // Otherwise show role selection.
      return '/select-role';

    case OnboardingStep.profileSetup:
      // Route to the appropriate profile setup based on role.
      if (role == UserRole.recruiter) return '/recruiter-profile-setup';
      if (role == UserRole.candidate) return '/candidate-profile-setup';
      // Admin goes straight to dashboard.
      return '/dashboard';

    case OnboardingStep.complete:
      return '/dashboard';

    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// GoRoute definitions — add these to your GoRouter(routes: [...]) collection:
// ---------------------------------------------------------------------------
//
// GoRoute(
//   path: '/verify-email',
//   name: 'verifyEmail',
//   builder: (_) => const VerifyEmailScreen(),
// ),
// GoRoute(
//   path: '/select-role',
//   name: 'selectRole',
//   builder: (_) => const RoleSelectionScreen(),
// ),
// GoRoute(
//   path: '/recruiter-profile-setup',
//   name: 'recruiterProfileSetup',
//   builder: (_) => const RecruiterProfileSetupScreen(),
// ),
// GoRoute(
//   path: '/candidate-profile-setup',
//   name: 'candidateProfileSetup',
//   builder: (_) => const CandidateProfileSetupScreen(),
// ),
// GoRoute(
//   path: '/profile-setup-complete',
//   name: 'profileSetupComplete',
//   builder: (_) => const ProfileSetupCompleteScreen(),
// ),
// GoRoute(
//   path: '/dashboard',
//   name: 'dashboard',
//   builder: (_) => const DashboardScreen(), // role-dependent scaffold
// ),