import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import '../widgets/account_tab_widget.dart';
import '../widgets/profile_information_tab.widget.dart';
import '../widgets/security_tab_widget.dart';

/// Body content for the /settings route — AppShell already provides the
/// sidebar/topbar. Notifications isn't a tab here since it already exists
/// as its own screen elsewhere for both roles; add a third tab alongside
/// Account/Security or Profile Information/Security & Privacy if another
/// settings category shows up later.
///
/// Candidates and recruiters see different first-tab content (different
/// fields entirely — phone/work-preferences vs competencies/
/// certifications) but share the same Security tab content, since
/// password/2FA/sessions/logs aren't role-specific.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecruiter =
        ref.watch(authProvider).user?.role == UserRole.recruiter;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isRecruiter
                ? 'Manage your global talent acquisition workspace and recruiter profile preferences.'
                : 'Manage your personal information, security preferences, and notification settings.',
            style: const TextStyle(color: BrandColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.orange,
            unselectedLabelColor: BrandColors.muted,
            indicatorColor: AppColors.orange,
            indicatorSize: TabBarIndicatorSize.label,
            // FIX: was using Tab's `icon`/`iconMargin` (which stacks icon
            // above the label — a vertical layout) alongside a `child` Row
            // that assumed a horizontal one. The two fought each other,
            // which is what was throwing the spacing off. Building the
            // whole tab as one Row in `child` and dropping `icon`/
            // `iconMargin` entirely fixes the layout; symmetric
            // labelPadding replaces the old right-only padding so the gap
            // on both sides of each tab is even.
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(
                height: 36,
                child: _TabLabel(
                  icon: Icons.person_outline,
                  label: isRecruiter ? 'Account' : 'Profile Information',
                ),
              ),
              Tab(
                height: 36,
                child: _TabLabel(
                  icon: Icons.shield_outlined,
                  label: isRecruiter ? 'Security' : 'Security & Privacy',
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                isRecruiter
                    ? const AccountTab()
                    : const ProfileInformationTab(),
                const SecurityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + label as one horizontal unit — relies on TabBar's built-in
/// IconTheme/DefaultTextStyle wrapping (from labelColor/
/// unselectedLabelColor) to animate both the icon and text color
/// together, so neither needs an explicit color here.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
