import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/core/network/dio_provider.dart';
import '../data/models/notification_models.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(dioProvider)));

final unreadNotificationCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
  final repository = ref.watch(notificationsRepositoryProvider);
  while (true) {
    try {
      yield await repository.getUnreadCount();
    } catch (_) {
      // Keep polling so a temporary offline period does not stop badge sync.
    }
    await Future<void>.delayed(const Duration(seconds: 30));
  }
});

class NotificationsState {
  const NotificationsState(
      {this.items = const [],
      this.isLoading = false,
      this.error,
      this.page = 0,
      this.hasMore = true,
      this.unreadCount = 0});
  final List<AppNotification> items;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;
  final int unreadCount;

  NotificationsState copyWith(
          {List<AppNotification>? items,
          bool? isLoading,
          String? error,
          int? page,
          bool? hasMore,
          int? unreadCount}) =>
      NotificationsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState());
  final NotificationsRepository _repository;

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.loadNotifications();
      state = state.copyWith(
          items: result.items,
          page: 1,
          hasMore: result.hasMore,
          unreadCount: result.unreadCount,
          isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.loadNotifications();
      state = state.copyWith(
          items: result.items,
          page: 1,
          hasMore: result.hasMore,
          unreadCount: result.unreadCount,
          isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final nextPage = state.page + 1;
      final result = await _repository.loadNotifications(page: nextPage);
      state = state.copyWith(
          items: [...state.items, ...result.items],
          page: nextPage,
          hasMore: result.hasMore,
          unreadCount: result.unreadCount,
          isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> markAsRead(String id) async {
    final before = state.items;
    state = state.copyWith(items: [
      for (final item in before)
        item.id == id ? item.copyWith(isRead: true) : item
    ], unreadCount: (state.unreadCount - 1).clamp(0, 1 << 30));
    try {
      await _repository.markAsRead(id);
    } catch (error) {
      state = state.copyWith(items: before, error: error.toString());
    }
  }

  Future<void> markAllAsRead() async {
    final before = state.items;
    state = state.copyWith(
        items: [for (final item in before) item.copyWith(isRead: true)],
        unreadCount: 0);
    try {
      await _repository.markAllAsRead();
    } catch (error) {
      state = state.copyWith(items: before, error: error.toString());
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) =>
        NotificationsNotifier(ref.watch(notificationsRepositoryProvider)));
