import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talentbridge/core/theme/brand_color.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'package:talentbridge/features/notifications/application/notifications_provider.dart';
import 'package:talentbridge/features/notifications/data/models/notification_models.dart';

class NotificationBellButton extends ConsumerStatefulWidget {
  const NotificationBellButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton> {
  final _portalController = OverlayPortalController();
  final _link = LayerLink();
  Timer? _hideTimer;
  bool _previewVisible = false;

  void _showPreview() {
    _hideTimer?.cancel();
    if (!_previewVisible) {
      _previewVisible = true;
      _portalController.show();
      ref.read(notificationsProvider.notifier).refresh();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _previewVisible = false;
      _portalController.hide();
    });
  }

  void _openCenter() {
    _hideTimer?.cancel();
    _previewVisible = false;
    _portalController.hide();
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final width =
        (MediaQuery.sizeOf(context).width - 24).clamp(280.0, 360.0).toDouble();
    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (context) => Stack(children: [
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(-width + 34, 48),
          child: MouseRegion(
            onEnter: (_) => _hideTimer?.cancel(),
            onExit: (_) => _scheduleHide(),
            child: _NotificationPreview(
              width: width,
              onOpenCenter: _openCenter,
              onOpenNotification: (item) async {
                if (!item.isRead) {
                  await ref
                      .read(notificationsProvider.notifier)
                      .markAsRead(item.id);
                }
                if (!context.mounted) return;
                _openCenter();
                final path = item.actionPath;
                if (path != null && path.startsWith('/')) {
                  context.push(path);
                }
              },
            ),
          ),
        ),
      ]),
      child: CompositedTransformTarget(
        link: _link,
        child: MouseRegion(
          onEnter: (_) => _showPreview(),
          onExit: (_) => _scheduleHide(),
          child: IconButton(
            onPressed: _openCenter,
            tooltip:
                unread > 0 ? '$unread unread notifications' : 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child:
                  const Icon(Icons.notifications_none, color: BrandColors.navy),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPreview extends ConsumerWidget {
  const _NotificationPreview({
    required this.width,
    required this.onOpenCenter,
    required this.onOpenNotification,
  });

  final double width;
  final VoidCallback onOpenCenter;
  final ValueChanged<AppNotification> onOpenNotification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final items = state.items.take(5).toList();
    return Material(
      elevation: 18,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(children: [
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('A quick look at your latest updates',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ]),
              ),
              IconButton(
                tooltip: 'View all notifications',
                onPressed: onOpenCenter,
                icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              ),
            ]),
          ),
          const Divider(height: 1),
          if (state.isLoading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 18),
              child: Text('You’re all caught up.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...items.map((item) => _PreviewItem(
                  item: item,
                  onTap: () => onOpenNotification(item),
                )),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onOpenCenter,
              child: const Text('View all notifications'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  const _PreviewItem({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: item.color.withValues(alpha: .12),
              child: Icon(item.icon, color: item.color, size: 17),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800)),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle)),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.3)),
                    const SizedBox(height: 5),
                    Text('${item.category.label} · ${item.timeLabel}',
                        style: TextStyle(
                            color: item.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ]),
        ),
      );
}
