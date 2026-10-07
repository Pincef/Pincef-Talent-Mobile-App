import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../data/candidate_messages_repository.dart';
import 'presence_provider.dart';
// Reuse the same socket-backed notifier + ChatMessage model as the
// recruiter side — a conversation behaves identically from either end,
// so there is exactly one place (messages_provider.dart) that knows how
// to talk to the socket.
export 'messages_provider.dart' show conversationProvider, typingProvider;

final candidateMessagesRepositoryProvider =
    Provider<CandidateMessagesRepository>(
  (ref) => CandidateMessagesRepository(ref.watch(dioProvider)),
);

/// Same live-update + presence-subscription shape as ThreadListNotifier on
/// the recruiter side (messages_provider.dart) — kept as a separate class
/// rather than a shared generic since CandidateChatContact and
/// MessageThread are different types, same as how this codebase already
/// keeps JobApplicantsNotifier and BrowseJobsNotifier separate despite a
/// similar shape.
class CandidateContactsNotifier
    extends StateNotifier<AsyncValue<List<CandidateChatContact>>> {
  CandidateContactsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(presenceProvider, (_, __) {});
    _threadSub = _socket.onThreadUpdate.listen(_onThreadUpdate);
    _load();
  }

  final Ref _ref;
  StreamSubscription? _threadSub;

  ChatSocketService get _socket => _ref.read(chatSocketProvider);

  Future<void> _load() async {
    try {
      final contacts =
          await _ref.read(candidateMessagesRepositoryProvider).getContacts();
      state = AsyncValue.data(contacts);
      _ref
          .read(presenceProvider.notifier)
          .subscribe(contacts.map((c) => c.partnerId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => _load();

  void _onThreadUpdate(Map<String, dynamic> event) {
    final current = state.valueOrNull;
    if (current == null) return;
    final conversationId = event['conversationId'] as String?;
    if (conversationId == null) return;

    final index = current.indexWhere((c) => c.id == conversationId);
    if (index == -1) {
      _load(); // brand-new thread — see the matching comment on the recruiter side
      return;
    }

    final updated = current[index].copyWith(
      preview: event['lastMessagePreview'] as String?,
      time: event['lastMessageAt'] as String?,
      unreadCount: (event['unreadCount'] as num?)?.toInt(),
    );
    final rest = [...current]..removeAt(index);
    state = AsyncValue.data([updated, ...rest]);
  }

  @override
  void dispose() {
    _threadSub?.cancel();
    final partnerIds =
        state.valueOrNull?.map((c) => c.partnerId) ?? const <String>[];
    _ref.read(presenceProvider.notifier).unsubscribe(partnerIds);
    super.dispose();
  }
}

final candidateContactsProvider = StateNotifierProvider.autoDispose<
    CandidateContactsNotifier, AsyncValue<List<CandidateChatContact>>>(
  (ref) => CandidateContactsNotifier(ref),
);

final selectedCandidateContactProvider = StateProvider<String?>((ref) => null);
