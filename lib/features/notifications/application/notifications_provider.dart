import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification_models.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider((ref) => NotificationsRepository());

class NotificationsState {
  const NotificationsState({this.items = const [], this.isLoading = false, this.error});
  final List<AppNotification> items;
  final bool isLoading;
  final String? error;

  NotificationsState copyWith({List<AppNotification>? items, bool? isLoading, String? error}) => NotificationsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository, this._isRecruiter) : super(const NotificationsState(isLoading: true)) {
    load();
  }

  final NotificationsRepository _repository;
  final bool _isRecruiter;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repository.loadNotifications(isRecruiter: _isRecruiter);
      state = state.copyWith(items: items, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> markAllAsRead() async {
    final unread = state.items.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    state = state.copyWith(items: [for (final item in state.items) item.copyWith(isRead: true)]);
    try {
      await _repository.markAllAsRead();
    } catch (error) {
      state = state.copyWith(items: [for (final item in state.items) item.copyWith(isRead: unread.any((old) => old.id == item.id) ? false : item.isRead)], error: error.toString());
    }
  }
}

final notificationsProvider = StateNotifierProvider.family<NotificationsNotifier, NotificationsState, bool>((ref, isRecruiter) {
  return NotificationsNotifier(ref.watch(notificationsRepositoryProvider), isRecruiter);
});
