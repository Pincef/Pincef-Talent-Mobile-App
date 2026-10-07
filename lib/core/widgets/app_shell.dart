import 'package:flutter/material.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';

class NavItem {
  final String label;
  final IconData icon;
  final List<NavItem> children;

  /// The go_router path this item navigates to when tapped. Null means
  /// there's no screen for it yet — AppShellRoute falls back to the
  /// nearest parent's route when a child has none (see app_shell_route.dart).
  final String? route;

  const NavItem(
      {required this.label,
      required this.icon,
      this.children = const [],
      this.route});
}

const List<NavItem> kCandidateNavItems = [
  NavItem(
      label: 'DASHBOARD', icon: Icons.grid_view_rounded, route: '/dashboard'),
  NavItem(label: 'BROWSE JOBS', icon: Icons.work_outline, route: '/jobs'),
  NavItem(
    label: 'APPLICATIONS',
    icon: Icons.people_outline,
    children: [
      NavItem(
        label: 'My Applications',
        icon: Icons.circle,
        route: '/applications',
      ),
      NavItem(
        label: 'Interviews',
        icon: Icons.circle,
        route: '/applications',
      ),
    ],
  ),
  NavItem(
      label: 'MESSAGES', icon: Icons.chat_bubble_outline, route: '/messages'),
  NavItem(label: 'SETTINGS', icon: Icons.settings_outlined, route: '/settings'),
];

const List<NavItem> kRecruiterNavItems = [
  NavItem(
      label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/dashboard'),
  NavItem(
    label: 'Jobs',
    icon: Icons.work_outline,
    route: '/jobs',
    children: [
      NavItem(label: 'Competence Based Assessment', icon: Icons.circle),
    ],
  ),
  NavItem(
    label: 'Candidates',
    icon: Icons.people_outline,
    children: [
      NavItem(label: 'Candidate Comparison', icon: Icons.circle),
    ],
  ),
  NavItem(
    label: 'Report',
    icon: Icons.bar_chart_outlined,
    children: [
      NavItem(
          label: 'Recruitment Report Generation',
          icon: Icons.circle,
          route: '/reports'),
    ],
  ),
  NavItem(
    label: 'CV Upload',
    icon: Icons.upload_file_outlined,
    children: [
      NavItem(label: 'AI CV Parsing', icon: Icons.circle),
      NavItem(label: 'AI Resume Summary', icon: Icons.circle),
      NavItem(label: 'AI CV-to-Job Matching', icon: Icons.circle),
      NavItem(label: 'AI Candidate Ranking', icon: Icons.circle),
    ],
  ),
  NavItem(
      label: 'Message', icon: Icons.chat_bubble_outline, route: '/messages'),
  NavItem(
      label: 'Interview',
      icon: Icons.calendar_today_outlined,
      route: '/interviews'),
  NavItem(
      label: 'Hiring Pipelines',
      icon: Icons.account_tree_outlined,
      route: '/hiring-pipelines'),
  NavItem(
    label: 'Payment & Subscription',
    icon: Icons.payments_outlined,
    route: '/payments',
  ),
  NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
];

const List<NavItem> kAdminNavItems = [
  NavItem(label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/admin'),
  NavItem(label: 'Users', icon: Icons.people_outline, route: '/admin/users'),
  NavItem(label: 'Jobs', icon: Icons.work_outline, route: '/admin/jobs'),
  NavItem(
    label: 'Tickets',
    icon: Icons.support_agent_outlined,
    route: '/admin/tickets',
  ),
  NavItem(
    label: 'Subscriptions',
    icon: Icons.payments_outlined,
    route: '/admin/subscriptions',
  ),
];

/// Desktop/web: fixed sidebar. Mobile: hamburger -> drawer, reusing the
/// exact same nav content as the desktop sidebar (previously a bottom
/// NavigationBar, which can't represent nested items like the recruiter
/// nav's Jobs/Candidates/Reports/CV-upload sub-menus — a drawer can).
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.onNavTap,
    required this.body,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    required this.userLocation,
    this.profileImageUrl,
    this.navItems = kCandidateNavItems,
    this.currentSubIndex,
    this.showSidebarUserCard = true,
    this.topBarUserName,
    this.topBarUserRole,
    this.primaryActionLabel = 'Upload CV',
    this.primaryActionIcon = Icons.add,
    this.showSecondaryAction = false,
    this.onSubItemTap,
    this.onUploadCv,
    this.onSearch,
    this.onNotifications,
    this.onProfileTap,
    this.onSupport,
    this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final String userName;
  final String userRole;
  final String userEmail;
  final String userLocation;

  /// Avatar image for both the sidebar user card and the topbar/AppBar
  /// avatar. Null falls back to the plain person icon everywhere, same
  /// as before this existed.
  final String? profileImageUrl;

  /// Which nav list to render — defaults to the candidate list so existing
  /// callers (CandidateDashboardScreen etc.) don't need to change.
  final List<NavItem> navItems;

  /// Highlights a specific child under navItems[currentIndex], e.g. for a
  /// screen that IS one of the sub-pages. Null (default) highlights only
  /// the top-level item, same as before this param existed.
  final int? currentSubIndex;

  /// The candidate mockup shows a sidebar card with avatar/name/role/email/
  /// location; the recruiter mockup doesn't. Set false to hide it entirely
  /// rather than render it with blank fields.
  final bool showSidebarUserCard;

  /// Shown next to the topbar avatar (recruiter mockup); left null (the
  /// default) the topbar stays icon-only, matching the candidate mockup.
  final String? topBarUserName;
  final String? topBarUserRole;

  final String primaryActionLabel;
  final IconData primaryActionIcon;

  /// Recruiter mockup shows a second "Upload resume" button below the
  /// primary action; candidate sidebar should show only the single
  /// primary action ("Upload CV") and nothing else. Defaults to false so
  /// the candidate case (the default navItems/primaryActionLabel above)
  /// stays single-button unless a caller opts in.
  final bool showSecondaryAction;

  /// Optional — only needed if you want sub-items to navigate anywhere.
  final void Function(int topLevelIndex, int subIndex)? onSubItemTap;

  final VoidCallback? onUploadCv;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return _DesktopShell(
        currentIndex: currentIndex,
        currentSubIndex: currentSubIndex,
        onNavTap: onNavTap,
        body: body,
        userName: userName,
        userRole: userRole,
        userEmail: userEmail,
        userLocation: userLocation,
        profileImageUrl: profileImageUrl,
        navItems: navItems,
        showSidebarUserCard: showSidebarUserCard,
        topBarUserName: topBarUserName,
        topBarUserRole: topBarUserRole,
        primaryActionLabel: primaryActionLabel,
        primaryActionIcon: primaryActionIcon,
        showSecondaryAction: showSecondaryAction,
        onSubItemTap: onSubItemTap,
        onUploadCv: onUploadCv,
        onSearch: onSearch,
        onNotifications: onNotifications,
        onProfileTap: onProfileTap,
        onSupport: onSupport,
        onLogout: onLogout,
      );
    }

    return _MobileShell(
      currentIndex: currentIndex,
      currentSubIndex: currentSubIndex,
      onNavTap: onNavTap,
      body: body,
      navItems: navItems,
      userName: userName,
      userRole: userRole,
      userEmail: userEmail,
      userLocation: userLocation,
      profileImageUrl: profileImageUrl,
      showSidebarUserCard: showSidebarUserCard,
      primaryActionLabel: primaryActionLabel,
      primaryActionIcon: primaryActionIcon,
      showSecondaryAction: showSecondaryAction,
      onSubItemTap: onSubItemTap,
      onNotifications: onNotifications,
      onProfileTap: onProfileTap,
      onUploadCv: onUploadCv,
      onSupport: onSupport,
      onLogout: onLogout,
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.currentIndex,
    this.currentSubIndex,
    required this.onNavTap,
    required this.body,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    required this.userLocation,
    this.profileImageUrl,
    required this.navItems,
    required this.showSidebarUserCard,
    this.topBarUserName,
    this.topBarUserRole,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    this.showSecondaryAction = false,
    this.onSubItemTap,
    this.onUploadCv,
    this.onSearch,
    this.onNotifications,
    this.onProfileTap,
    this.onSupport,
    this.onLogout,
  });

  final int currentIndex;
  final int? currentSubIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final String userName;
  final String userRole;
  final String userEmail;
  final String userLocation;
  final String? profileImageUrl;
  final List<NavItem> navItems;
  final bool showSidebarUserCard;
  final String? topBarUserName;
  final String? topBarUserRole;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final bool showSecondaryAction;
  final void Function(int topLevelIndex, int subIndex)? onSubItemTap;
  final VoidCallback? onUploadCv;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          _Sidebar(
            currentIndex: currentIndex,
            currentSubIndex: currentSubIndex,
            onNavTap: onNavTap,
            userName: userName,
            userRole: userRole,
            userEmail: userEmail,
            userLocation: userLocation,
            profileImageUrl: profileImageUrl,
            navItems: navItems,
            showUserCard: showSidebarUserCard,
            primaryActionLabel: primaryActionLabel,
            primaryActionIcon: primaryActionIcon,
            showSecondaryAction: showSecondaryAction,
            onSubItemTap: onSubItemTap,
            onUploadCv: onUploadCv,
            onSupport: onSupport,
            onLogout: onLogout,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  onSearch: onSearch,
                  onNotifications: onNotifications,
                  onProfileTap: onProfileTap,
                  userName: topBarUserName,
                  userRole: topBarUserRole,
                  profileImageUrl: profileImageUrl,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.currentIndex,
    this.currentSubIndex,
    required this.onNavTap,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    required this.userLocation,
    this.profileImageUrl,
    required this.navItems,
    required this.showUserCard,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    this.showSecondaryAction = false,
    this.onSubItemTap,
    this.onUploadCv,
    this.onSupport,
    this.onLogout,
    this.width = 232,
  });

  final int currentIndex;
  final int? currentSubIndex;
  final ValueChanged<int> onNavTap;
  final String userName;
  final String userRole;
  final String userEmail;
  final String userLocation;
  final String? profileImageUrl;
  final List<NavItem> navItems;
  final bool showUserCard;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final bool showSecondaryAction;
  final void Function(int topLevelIndex, int subIndex)? onSubItemTap;
  final VoidCallback? onUploadCv;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;
  final double width;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  // Groups with sub-items default to expanded, matching the mockup
  // (every group shown open simultaneously) — tap a group header to
  // collapse/expand it.
  late final Set<int> _expanded = {
    for (var i = 0; i < widget.navItems.length; i++)
      if (widget.navItems[i].children.isNotEmpty) i,
  };

  @override
  Widget build(BuildContext context) {
    // The sidebar uses the same light surface and navigation treatment for
    // both roles.  Role-specific content (such as the candidate user card)
    // remains unchanged.
    const foreground = BrandColors.navy;
    const muted = BrandColors.muted;
    return Container(
      width: widget.width,
      decoration: const BoxDecoration(
        gradient: BrandColors.gradient,
        // border: Border.all(color: const Color(0xFF239BFF), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'lib/assets/images/logo.jpeg',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PINCEF TALENTBRIDGE',
                      style: TextStyle(
                          color: BrandColors.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Global Talent Acquisition',
                      style: TextStyle(color: BrandColors.muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // FIX: userName/userEmail/userLocation/showUserCard were already
          // threaded all the way down from AppShell but nothing here ever
          // rendered them — this card (avatar/name/role/email/location,
          // per the candidate mockup) was dead plumbing until now.
          if (widget.showUserCard) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: widget.profileImageUrl != null
                        ? NetworkImage(widget.profileImageUrl!)
                        : null,
                    child: widget.profileImageUrl == null
                        ? const Icon(Icons.person,
                            color: BrandColors.navy, size: 22)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: BrandColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    widget.userRole,
                    style: TextStyle(
                      color: BrandColors.navy.withValues(alpha: 0.75),
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 11, color: BrandColors.navy),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.userEmail,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: BrandColors.navy, fontSize: 8.5),
                        ),
                      ),
                    ],
                  ),
                  if (widget.userLocation.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: BrandColors.navy),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.userLocation,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: BrandColors.navy, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                    widget.navItems.length, (index) => _buildNavGroup(index)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
              ),
              onPressed: widget.onUploadCv,
              icon: Icon(widget.primaryActionIcon, size: 14),
              label: Text(widget.primaryActionLabel,
                  style: const TextStyle(fontSize: 10.5)),
            ),
          ),
          // Recruiter mockup shows a second "Upload resume" action below
          // the primary button; candidate sidebar should only ever show
          // the single primary action above. This was previously
          // unconditional, so candidates got two buttons that both just
          // called onUploadCv.
          if (widget.showSecondaryAction) ...[
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onUploadCv,
                icon: const Icon(Icons.file_upload_outlined, size: 14),
                label: const Text('Upload resume',
                    style:
                        TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.navy,
                  side: const BorderSide(color: BrandColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: BrandColors.border, height: 1),
          const SizedBox(height: 6),
          if (widget.onSupport != null)
            _SidebarFooterLink(
                icon: Icons.help_outline,
                label: 'Support',
                color: muted,
                onTap: widget.onSupport),
          _SidebarFooterLink(
              icon: Icons.logout,
              label: 'Logout',
              color: muted,
              onTap: widget.onLogout),
        ],
      ),
    );
  }

  Widget _buildNavGroup(int index) {
    final item = widget.navItems[index];
    final selected =
        index == widget.currentIndex && widget.currentSubIndex == null;
    final hasChildren = item.children.isNotEmpty;
    final isExpanded = _expanded.contains(index);
    const foreground = BrandColors.navy;
    const muted = BrandColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? BrandColors.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: selected
                  ? const Border(
                      right: BorderSide(color: BrandColors.orange, width: 3))
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  widget.onNavTap(index);
                  if (hasChildren) {
                    setState(() {
                      if (isExpanded) {
                        _expanded.remove(index);
                      } else {
                        _expanded.add(index);
                      }
                    });
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          size: 15,
                          color: selected ? Colors.white : foreground),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? Colors.white : foreground,
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasChildren)
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 15,
                          color: selected ? Colors.white : muted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 29, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(item.children.length, (subIndex) {
                final sub = item.children[subIndex];
                final subSelected = index == widget.currentIndex &&
                    subIndex == widget.currentSubIndex;
                return Container(
                  decoration: BoxDecoration(
                    color: subSelected ? BrandColors.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: subSelected
                        ? const Border(
                            right:
                                BorderSide(color: BrandColors.orange, width: 3))
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: () => widget.onSubItemTap?.call(index, subIndex),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 5),
                        child: Text(
                          sub.label,
                          style: TextStyle(
                            color: subSelected ? Colors.white : muted,
                            fontSize: 8.5,
                            fontWeight:
                                subSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _SidebarFooterLink extends StatelessWidget {
  const _SidebarFooterLink(
      {required this.icon,
      required this.label,
      this.color = BrandColors.muted,
      this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {this.onSearch,
      this.onNotifications,
      this.onProfileTap,
      this.userName,
      this.userRole,
      this.profileImageUrl})
      : leading = null;

  final ValueChanged<String>? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final String? userName;
  final String? userRole;
  final String? profileImageUrl;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: TextField(
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: 'Search candidates, jobs...',
                  hintStyle: const TextStyle(color: BrandColors.navy),
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: BrandColors.navy),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none, color: BrandColors.navy),
          ),
          const SizedBox(width: 12),
          if (userName != null) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  userName!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                if (userRole != null)
                  Text(userRole!,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textPrimary.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(width: 10),
          ],
          InkWell(
            onTap: onProfileTap,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.peach,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl!)
                  : null,
              child: profileImageUrl == null
                  ? const Icon(Icons.person, color: AppColors.orange, size: 18)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.currentIndex,
    this.currentSubIndex,
    required this.onNavTap,
    required this.body,
    required this.navItems,
    required this.userName,
    required this.userRole,
    required this.userEmail,
    required this.userLocation,
    this.profileImageUrl,
    required this.showSidebarUserCard,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    this.showSecondaryAction = false,
    this.onSubItemTap,
    this.onNotifications,
    this.onProfileTap,
    this.onUploadCv,
    this.onSupport,
    this.onLogout,
  });

  final int currentIndex;
  final int? currentSubIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;
  final List<NavItem> navItems;
  final String userName;
  final String userRole;
  final String userEmail;
  final String userLocation;
  final String? profileImageUrl;
  final bool showSidebarUserCard;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final bool showSecondaryAction;
  final void Function(int topLevelIndex, int subIndex)? onSubItemTap;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfileTap;
  final VoidCallback? onUploadCv;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // Providing `drawer:` makes Flutter automatically add the hamburger
      // icon to the AppBar's leading slot — no manual wiring needed.
      drawer: Drawer(
        backgroundColor: AppColors.navy,
        child: SizedBox(
          width: 304,
          height: MediaQuery.sizeOf(context).height,
          child: SafeArea(
            child: _Sidebar(
              currentIndex: currentIndex,
              currentSubIndex: currentSubIndex,
              onNavTap: (index) {
                Navigator.of(context).pop(); // close the drawer on nav
                onNavTap(index);
              },
              userName: userName,
              userRole: userRole,
              userEmail: userEmail,
              userLocation: userLocation,
              profileImageUrl: profileImageUrl,
              navItems: navItems,
              showUserCard: showSidebarUserCard,
              primaryActionLabel: primaryActionLabel,
              primaryActionIcon: primaryActionIcon,
              onSubItemTap: (top, sub) {
                Navigator.of(context).pop();
                onSubItemTap?.call(top, sub);
              },
              onUploadCv: () {
                Navigator.of(context).pop();
                onUploadCv?.call();
              },
              onSupport: onSupport,
              onLogout: () {
                Navigator.of(context).pop();
                onLogout?.call();
              },
              width: 304,
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title:
            const Text('PINCEF TalentBridge', style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none)),
          IconButton(
            onPressed: onProfileTap,
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.peach,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl!)
                  : null,
              child: profileImageUrl == null
                  ? const Icon(Icons.person, size: 14, color: AppColors.orange)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        onPressed: onUploadCv,
        icon: Icon(primaryActionIcon),
        label: Text(primaryActionLabel),
      ),
    );
  }
}
