import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/models/user_model.dart';

/// Remembers which role the user picked on the welcome screen
/// ('Get Started' vs 'Create Recruiter Account') so the signup
/// screen that follows knows which form/fields to render.
///
/// Lives in onboarding because that's where it's set; auth's signup
/// screens import it from here (one-directional dependency).
final selectedRoleProvider = StateProvider<UserRole?>((ref) => null);