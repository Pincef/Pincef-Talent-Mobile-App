/// lib/features/settings/application/settings_provider.dart
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talentbridge/features/auth/application/auth_provider.dart';
import '../data/models/security_log_item_model.dart';
import '../data/setting_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(dioProvider));
});

class SecurityLogState {
  final List<SecurityLogItem> items;
  final String? nextCursor;
  final bool isLoadingMore;

  const SecurityLogState({
    this.items = const [],
    this.nextCursor,
    this.isLoadingMore = false,
  });

  SecurityLogState copyWith({
    List<SecurityLogItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
  }) {
    return SecurityLogState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SecurityLogNotifier extends StateNotifier<AsyncValue<SecurityLogState>> {
  SecurityLogNotifier(this._repository) : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  final SettingsRepository _repository;

  Future<void> _loadFirstPage() async {
    try {
      final page = await _repository.getSecurityLogs();
      state = AsyncValue.data(
          SecurityLogState(items: page.items, nextCursor: page.nextCursor));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final page =
          await _repository.getSecurityLogs(cursor: current.nextCursor);
      state = AsyncValue.data(current.copyWith(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final securityLogProvider = StateNotifierProvider.autoDispose<
    SecurityLogNotifier, AsyncValue<SecurityLogState>>((ref) {
  return SecurityLogNotifier(ref.watch(settingsRepositoryProvider));
});
