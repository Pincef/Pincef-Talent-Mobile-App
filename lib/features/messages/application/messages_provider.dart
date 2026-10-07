import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/auth_provider.dart' hide dioProvider;
import '../../../core/network/dio_provider.dart';
import '../../../core/realtime/socket_service.dart';
import '../data/messages_repository.dart';
import 'presence_provider.dart';

const _uuid = Uuid();

final messagesRepositoryProvider = Provider<MessagesRepository>(
    (ref) => MessagesRepository(ref.watch(dioProvider)));

/// Backs the recruiter's inbox list. Beyond the initial fetch, this also:
///  - merges live `thread:update` events (new message previews/unread
///    counts on threads you're not currently inside), bumping the updated
///    thread to the top the way a real inbox does
///  - subscribes/unsubscribes presence for every thread's partner, so the
///    list can show an online dot without a separate screen having to
///    remember to do it
/// autoDispose for the same staleness reasons as the rest of this file —
/// without it, this would survive navigation away and even logout/login.
class ThreadListNotifier
    extends StateNotifier<AsyncValue<List<MessageThread>>> {
  ThreadListNotifier(this._ref) : super(const AsyncValue.loading()) {
    // ref.listen (not ref.watch) on purpose: this keeps presenceProvider
    // alive for as long as this notifier is, without the presence map
    // changing (which happens constantly — someone going online/offline)
    // triggering a full recreation of this notifier and its thread list.
    _ref.listen(presenceProvider, (_, __) {});
    _threadSub = _socket.onThreadUpdate.listen(_onThreadUpdate);
    _load();
  }

  final Ref _ref;
  StreamSubscription? _threadSub;

  ChatSocketService get _socket => _ref.read(chatSocketProvider);

  Future<void> _load() async {
    try {
      final threads = await _ref.read(messagesRepositoryProvider).getThreads();
      state = AsyncValue.data(threads);
      _ref
          .read(presenceProvider.notifier)
          .subscribe(threads.map((t) => t.partnerId));
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

    final index = current.indexWhere((t) => t.id == conversationId);
    if (index == -1) {
      // A thread that isn't in our current list yet — e.g. this is the
      // very first message on a conversation someone just started with
      // us. thread:update only carries a partial summary, not everything
      // MessageThread needs (candidate name, job title), so the correct
      // move is a full refetch rather than half-constructing a row.
      _load();
      return;
    }

    final updated = current[index].copyWith(
      preview: event['lastMessagePreview'] as String?,
      time: event['lastMessageAt'] as String?,
      unreadCount: (event['unreadCount'] as num?)?.toInt(),
    );
    final rest = [...current]..removeAt(index);
    state =
        AsyncValue.data([updated, ...rest]); // bump to top, like a real inbox
  }

  @override
  void dispose() {
    _threadSub?.cancel();
    final partnerIds =
        state.valueOrNull?.map((t) => t.partnerId) ?? const <String>[];
    _ref.read(presenceProvider.notifier).unsubscribe(partnerIds);
    super.dispose();
  }
}

final messageThreadsProvider = StateNotifierProvider.autoDispose<
    ThreadListNotifier, AsyncValue<List<MessageThread>>>(
  (ref) => ThreadListNotifier(ref),
);

final selectedMessageThreadProvider = StateProvider<String?>((ref) => null);

/// One notifier per open conversation (family, keyed by conversationId).
/// Handles: initial history load, joining/leaving the socket room,
/// merging incoming messages, optimistic send + ack reconciliation, and
/// typing/read state.
class ConversationNotifier
    extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ConversationNotifier(this._ref, this.conversationId)
      : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref _ref;
  final String conversationId;
  StreamSubscription? _newSub;
  StreamSubscription? _ackSub;
  StreamSubscription? _readSub;

  ChatSocketService get _socket => _ref.read(chatSocketProvider);
  // TODO: confirm this is where the logged-in user's id actually lives —
  // carried over from before I'd seen your auth setup, same as the token
  // assumption this file used to make.
  String get _myUserId => _ref.read(authProvider).user!.id;

  Future<void> _init() async {
    try {
      final repo = _ref.read(messagesRepositoryProvider);
      final history = await repo.getConversation(conversationId, _myUserId);
      state = AsyncValue.data(history);

      _socket.joinConversation(conversationId);
      _socket.markRead(conversationId);

      _newSub = _socket.onNewMessage
          .where((m) => m['conversationId'] == conversationId)
          .listen(_onIncoming);
      _ackSub = _socket.onAck
          .where((m) => m['conversationId'] == conversationId)
          .listen(_onAck);
      _readSub = _socket.onReadReceipt
          .where((m) => m['conversationId'] == conversationId)
          .listen((_) => _markAllMineAsRead());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _onIncoming(Map<String, dynamic> json) {
    final message = ChatMessage.fromJson(json, myUserId: _myUserId);
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == message.id)) return; // already have it
    state = AsyncValue.data([...current, message]);
  }

  /// The server echoes the sender's own message back as an ack. Swap the
  /// optimistic placeholder (matched by clientId) for the real one instead
  /// of appending a second bubble.
  void _onAck(Map<String, dynamic> json) {
    final message = ChatMessage.fromJson(json, myUserId: _myUserId);
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere(
        (m) => m.clientId != null && m.clientId == message.clientId);
    if (index == -1) return _onIncoming(json);
    final updated = [...current];
    updated[index] = message;
    state = AsyncValue.data(updated);
  }

  void _markAllMineAsRead() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final m in current)
        m.isMine && m.status != MessageStatus.read
            ? ChatMessage(
                id: m.id,
                text: m.text,
                time: m.time,
                isMine: true,
                status: MessageStatus.read)
            : m,
    ]);
  }

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final clientId = _uuid.v4();

    final optimistic = ChatMessage(
      id: clientId,
      text: trimmed,
      time: DateTime.now().toIso8601String(),
      isMine: true,
      status: MessageStatus.sent,
      clientId: clientId,
    );
    state = AsyncValue.data([...(state.valueOrNull ?? []), optimistic]);

    if (_socket.isConnected) {
      _socket.send(
          conversationId: conversationId, text: trimmed, clientId: clientId);
    } else {
      // Socket briefly down (reconnecting) — fall back to REST so the
      // message isn't silently lost; the ack still arrives later over the
      // socket once it reconnects and reconciles the bubble as usual.
      _ref
          .read(messagesRepositoryProvider)
          .sendViaRest(conversationId, trimmed, clientId, _myUserId);
    }
  }

  void setTyping(bool isTyping) =>
      _socket.setTyping(conversationId: conversationId, isTyping: isTyping);

  @override
  void dispose() {
    _socket.leaveConversation(conversationId);
    _newSub?.cancel();
    _ackSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }
}

final conversationProvider = StateNotifierProvider.autoDispose
    .family<ConversationNotifier, AsyncValue<List<ChatMessage>>, String>(
  (ref, conversationId) => ConversationNotifier(ref, conversationId),
);

/// True while the other participant is typing in this conversation.
final typingProvider = StateProvider.autoDispose
    .family<bool, String>((ref, conversationId) => false);

/// Wires typingProvider up to the socket's typing:broadcast stream. Read
/// this once (e.g. in the conversation screen's initState/build) per
/// conversationId to start listening.
final typingListenerProvider =
    Provider.autoDispose.family<void, String>((ref, conversationId) {
  final socket = ref.watch(chatSocketProvider);
  final sub = socket.onTyping
      .where((e) => e['conversationId'] == conversationId)
      .listen((event) {
    ref.read(typingProvider(conversationId).notifier).state =
        event['isTyping'] as bool;
  });
  ref.onDispose(sub.cancel);
});
