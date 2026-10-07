import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/core/widgets/app_shell.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import 'package:talentbridge/features/auth/data/models/user_model.dart';
import 'package:talentbridge/features/notifications/application/notifications_provider.dart';
import 'package:talentbridge/features/notifications/data/models/notification_models.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  var _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isRecruiter = user?.role == UserRole.recruiter;
    final notificationState = ref.watch(notificationsProvider(isRecruiter));
    final notifications = notificationState.items;
    final visibleNotifications = _selectedTab == 0
        ? notifications
        : notifications.where((item) => item.category.label == _tabs[_selectedTab]).toList();

    return AppShell(
      currentIndex: 0,
      navItems: isRecruiter ? kRecruiterNavItems : kCandidateNavItems,
      showSidebarUserCard: !isRecruiter,
      topBarUserName: isRecruiter ? _name(user) : null,
      topBarUserRole: isRecruiter ? 'Recruiter' : null,
      userName: isRecruiter ? user?.firstName ?? 'Recruiter' : 'ALEX RIVERA',
      userRole: isRecruiter ? 'Recruiter' : 'Senior UI/UX Designer',
      userEmail: user?.email ?? 'alex.rivera@design.io',
      userLocation: isRecruiter ? '' : 'San Francisco, CA',
      primaryActionLabel: isRecruiter ? 'Post New Job' : 'Upload CV',
      primaryActionIcon: Icons.add,
      onNavTap: (index) {
        if (index == 0) context.go('/dashboard');
        if (!isRecruiter && index == 1) context.push('/jobs');
      },
      onNotifications: () {},
      onLogout: () async {
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
      body: notificationState.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notificationState.error != null && notifications.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(notificationState.error!),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => ref.read(notificationsProvider(isRecruiter).notifier).load(), child: const Text('Retry')),
                  ]),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => _NotificationBody(
                    isRecruiter: isRecruiter,
                    selectedTab: _selectedTab,
                    allRead: notifications.isNotEmpty && notifications.every((item) => item.isRead),
                    notifications: visibleNotifications,
                    isWide: constraints.maxWidth >= 820,
                    onTabSelected: (index) => setState(() => _selectedTab = index),
                    onMarkAllRead: () => ref.read(notificationsProvider(isRecruiter).notifier).markAllAsRead(),
                  ),
                ),
    );
  }

  String _name(UserModel? user) {
    if (user == null) return 'Recruiter';
    return '${user.firstName} ${user.lastName}';
  }
}

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({
    required this.isRecruiter,
    required this.selectedTab,
    required this.allRead,
    required this.notifications,
    required this.isWide,
    required this.onTabSelected,
    required this.onMarkAllRead,
  });

  final bool isRecruiter;
  final int selectedTab;
  final bool allRead;
  final List<AppNotification> notifications;
  final bool isWide;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(isRecruiter: isRecruiter, allRead: allRead, onMarkAllRead: onMarkAllRead),
        const SizedBox(height: 22),
        _NotificationTabs(selectedTab: selectedTab, onSelected: onTabSelected),
        const SizedBox(height: 18),
        const Text('TODAY', style: _sectionStyle),
        const SizedBox(height: 10),
        ...notifications.where((item) => item.isToday).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationCard(item: item, read: allRead),
            )),
        const SizedBox(height: 10),
        const Text('YESTERDAY', style: _sectionStyle),
        const SizedBox(height: 10),
        ...notifications.where((item) => !item.isToday).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationCard(item: item, read: allRead),
            )),
        TextButton(onPressed: () {}, child: const Text('Load older notifications')),
      ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: content),
                const SizedBox(width: 24),
                SizedBox(width: 250, child: _NotificationSidebar(isRecruiter: isRecruiter)),
              ],
            )
          : content,
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.isRecruiter, required this.allRead, required this.onMarkAllRead});

  final bool isRecruiter;
  final bool allRead;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notification Center', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                isRecruiter
                    ? 'Stay on top of applicants, interview activity and your open roles.'
                    : 'Stay updated with your latest job matches, application statuses, and interview schedules.',
                style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: allRead ? null : onMarkAllRead,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
          child: Text(allRead ? 'All caught up' : 'Mark all as read'),
        ),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune, size: 16),
          label: const Text('Preferences'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
        ),
      ],
    );
  }
}

class _NotificationTabs extends StatelessWidget {
  const _NotificationTabs({required this.selectedTab, required this.onSelected});

  final int selectedTab;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final selected = selectedTab == index;
          return InkWell(
            onTap: () => onSelected(index),
            child: Column(
              children: [
                Text(_tabs[index], style: TextStyle(fontSize: 12.5, color: selected ? AppColors.orange : AppColors.textSecondary, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                const Spacer(),
                Container(height: 2, width: 54, color: selected ? AppColors.orange : Colors.transparent),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.read});

  final AppNotification item;
  final bool read;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: read || item.isRead ? Colors.white : const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(12),
        // Flutter only allows BorderRadius with borders whose sides share
        // one color. The per-alert color is already represented by the icon.
        border: Border.all(color: item.isRead || read ? AppColors.divider : AppColors.peachBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: item.color.withValues(alpha: .14), child: Icon(item.icon, color: item.color, size: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))), Text(item.timeLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))]),
                const SizedBox(height: 5),
                Text(item.message, style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary)),
                if (item.actionLabel != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14), foregroundColor: AppColors.orange, side: const BorderSide(color: AppColors.peachBorder)), child: Text(item.actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSidebar extends StatelessWidget {
  const _NotificationSidebar({required this.isRecruiter});
  final bool isRecruiter;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SideCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 16), Row(children: [const Expanded(child: _Metric(value: '12', label: 'UNREAD', color: AppColors.orange)), const SizedBox(width: 10), Expanded(child: _Metric(value: isRecruiter ? '8' : '4', label: isRecruiter ? 'APPLICANTS' : 'INTERVIEWS', color: AppColors.statusMatchGreen))])])),
      const SizedBox(height: 18),
      Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('💡 Workspace Tip', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(isRecruiter ? 'Review shortlisted candidates within 24 hours to keep strong talent engaged.' : 'Candidates who respond to interview invites within 2 hours are more likely to land the offer.', style: const TextStyle(fontSize: 12, height: 1.45, color: Colors.white70)), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: AppColors.orange), child: const Text('Manage alerts')))])),
    ]);
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.peachBorder)), child: child);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF5F7FC), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)), child: Column(children: [Text(value, style: TextStyle(fontSize: 17, color: color, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary))]));
}

const _tabs = ['All Alerts', 'Job Matches', 'Applications', 'Messages'];

const _sectionStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: AppColors.textSecondary);
