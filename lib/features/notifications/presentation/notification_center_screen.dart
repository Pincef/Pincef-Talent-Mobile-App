import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/features/notifications/application/notifications_provider.dart';
import 'package:talentbridge/features/notifications/data/models/notification_models.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  var _selectedTab = 0;
  var _search = '';
  static const _tabs = [
    'All Notifications',
    'Candidates',
    'Assessments',
    'Interviews',
    'Jobs',
    'System',
    'Messages'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final category = _selectedTab == 0
        ? null
        : NotificationCategory.values
            .firstWhere((item) => item.label == _tabs[_selectedTab]);
    final notifications = state.items
        .where((item) =>
            (category == null || item.category == category) &&
            (item.title.toLowerCase().contains(_search.toLowerCase()) ||
                item.message.toLowerCase().contains(_search.toLowerCase())))
        .toList();

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      return RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: ListView(
            padding: EdgeInsets.fromLTRB(
                compact ? 14 : 24, compact ? 16 : 24, compact ? 14 : 24, 32),
            children: [
              if (compact) ...[
                const Text('Notifications',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: Text(
                          state.unreadCount > 0
                              ? '${state.unreadCount} new'
                              : 'Stay updated with your hiring pipeline activities.',
                          style:
                              const TextStyle(color: AppColors.textSecondary))),
                  if (state.unreadCount > 0)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(notificationsProvider.notifier)
                          .markAllAsRead(),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Read all'),
                    ),
                ]),
              ] else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          const Text('Notifications',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          const SizedBox(width: 14),
                          if (state.unreadCount > 0)
                            Text('${state.unreadCount} new',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orange))
                        ]),
                        const SizedBox(height: 6),
                        const Text(
                            'Stay updated with your hiring pipeline activities.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ])),
                  TextButton.icon(
                      onPressed: state.unreadCount == 0
                          ? null
                          : () => ref
                              .read(notificationsProvider.notifier)
                              .markAllAsRead(),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark all as read')),
                ]),
              const Divider(height: 28),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...List.generate(
                        _tabs.length,
                        (index) => ChoiceChip(
                            label: Text(_tabs[index]),
                            selected: index == _selectedTab,
                            onSelected: (_) =>
                                setState(() => _selectedTab = index))),
                    SizedBox(
                        width: compact
                            ? (constraints.maxWidth - 28)
                                .clamp(0, double.infinity)
                            : 260,
                        height: 44,
                        child: TextField(
                            onChanged: (value) =>
                                setState(() => _search = value),
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search notifications...',
                                border: OutlineInputBorder(),
                                isDense: true))),
                  ]),
              const SizedBox(height: 18),
              if (state.isLoading && state.items.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator()))
              else if (state.error != null && state.items.isEmpty)
                Center(
                    child: Column(children: [
                  Text(state.error!),
                  TextButton(
                      onPressed: () =>
                          ref.read(notificationsProvider.notifier).refresh(),
                      child: const Text('Retry'))
                ]))
              else if (notifications.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Center(
                        child: Text('No notifications to show.',
                            style: TextStyle(color: AppColors.textSecondary))))
              else
                ...notifications.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotificationCard(
                        item: item,
                        onOpen: () async {
                          if (!item.isRead) {
                            await ref
                                .read(notificationsProvider.notifier)
                                .markAsRead(item.id);
                          }
                          if (!context.mounted) return;
                          final path = item.actionPath;
                          if (path != null && path.startsWith('/')) {
                            context.push(path);
                          }
                        }))),
              if (state.hasMore)
                Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () => ref
                                .read(notificationsProvider.notifier)
                                .loadMore(),
                        icon: const Icon(Icons.keyboard_arrow_down),
                        label: Text(state.isLoading
                            ? 'Loading...'
                            : 'Load older notifications'))),
              if (state.error != null && state.items.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(state.error!,
                        style: const TextStyle(color: Colors.red))),
            ]),
      );
    });
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onOpen});
  final AppNotification item;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
        color: item.isRead ? Colors.white : const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: item.isRead
                          ? AppColors.divider
                          : AppColors.peachBorder)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                    backgroundColor: item.color.withValues(alpha: .13),
                    child: Icon(item.icon, color: item.color, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(item.category.label.toUpperCase(),
                                style: TextStyle(
                                    color: item.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .4)),
                            Text('• ${item.timeLabel}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12))
                          ]),
                      const SizedBox(height: 5),
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(item.message,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.textSecondary)),
                      if (item.actionLabel != null) ...[
                        const SizedBox(height: 10),
                        Text(item.actionLabel!,
                            style: const TextStyle(
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600))
                      ],
                    ])),
                if (!item.isRead)
                  const Padding(
                      padding: EdgeInsets.only(left: 10, top: 5),
                      child: CircleAvatar(
                          radius: 4,
                          backgroundColor: AppColors.statusMatchGreen)),
              ]),
            )),
      );
}
