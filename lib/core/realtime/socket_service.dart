import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/dio_provider.dart' show secureStorageServiceProvider;
import '../storage/secure_storage_service.dart';
import '../utils/app_config.dart';

/// One shared Socket.IO connection for the whole app (both the recruiter
/// and candidate messaging screens use this — a second connection per
/// screen would mean two sockets, two auth handshakes, and duplicate
/// events).
///
/// Token handling mirrors DioClient: the access token is read from the
/// same SecureStorageService Dio's auth interceptor uses, so there's one
/// source of truth for "what's the current token" instead of a second
/// copy living in some auth state object.
///
/// Usage from a provider/notifier:
///   final socket = ref.watch(chatSocketProvider);
///   socket.joinConversation(id);
///   socket.onNewMessage.listen((json) => ...);
///   socket.send(conversationId: id, text: text, clientId: uuid);
class ChatSocketService {
  ChatSocketService(this._storage);

  final SecureStorageService _storage;
  io.Socket? _socket;

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _ackController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _threadUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _presenceChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _presenceSnapshotController =
      StreamController<List<dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onAck => _ackController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onReadReceipt => _readController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  /// Fires whenever a message lands on ANY of this user's conversations —
  /// separate from onNewMessage/onAck, which are scoped to whichever
  /// conversation a ConversationNotifier is currently watching. This is
  /// what a thread LIST (as opposed to an open conversation) listens to,
  /// so the inbox updates live even for threads you're not currently in.
  Stream<Map<String, dynamic>> get onThreadUpdate =>
      _threadUpdateController.stream;

  /// One user's online/offline transition — only fires for userIds you've
  /// called [subscribePresence] for.
  Stream<Map<String, dynamic>> get onPresenceChanged =>
      _presenceChangedController.stream;

  /// Current state for a batch of userIds, delivered once right after
  /// [subscribePresence] — joining a room only carries future changes, so
  /// this is how a freshly opened thread list learns who's online *now*.
  Stream<List<dynamic>> get onPresenceSnapshot =>
      _presenceSnapshotController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Fire-and-forget: reads the current access token from secure storage
  /// and opens the connection. Safe to call before login — it just won't
  /// connect until a token exists; call it again (or [reconnectWithFreshToken])
  /// right after a successful login.
  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _storage.getAccessToken();
    if (token == null) return;
    _open(token);
  }

  /// Call this if the gateway rejects the handshake as unauthorized (token
  /// expired) — tears down the stale socket and reconnects with whatever
  /// token is currently in storage. In the normal case a REST call already
  /// triggered DioClient's refresh shortly before this fires, so the fresh
  /// token is usually already there by the time this runs.
  Future<void> reconnectWithFreshToken() async {
    _socket?.dispose();
    _socket = null;
    await connect();
  }

  void _open(String token) {
    final baseUrl = ApiConfig.baseUrl.replaceFirst('/api', '');
    _socket = io.io(
      '$baseUrl/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .build(),
    );

    _socket!
      ..onConnect((_) => _connectionController.add(true))
      ..onDisconnect((_) => _connectionController.add(false))
      ..onConnectError((_) => reconnectWithFreshToken())
      ..on('message:new',
          (data) => _newMessageController.add(Map<String, dynamic>.from(data)))
      ..on('message:ack',
          (data) => _ackController.add(Map<String, dynamic>.from(data)))
      ..on('typing:broadcast',
          (data) => _typingController.add(Map<String, dynamic>.from(data)))
      ..on('message:read:broadcast',
          (data) => _readController.add(Map<String, dynamic>.from(data)))
      ..on(
          'thread:update',
          (data) =>
              _threadUpdateController.add(Map<String, dynamic>.from(data)))
      ..on(
          'presence:changed',
          (data) =>
              _presenceChangedController.add(Map<String, dynamic>.from(data)))
      ..on(
          'presence:snapshot',
          (data) => _presenceSnapshotController
              .add(List<dynamic>.from((data as Map)['entries'] as List)));
  }

  /// Call once you know which userIds' presence you actually care about —
  /// typically every conversation partner in the currently loaded thread
  /// list. Delivers an immediate [onPresenceSnapshot] for these ids, then
  /// [onPresenceChanged] for any of them going forward.
  void subscribePresence(List<String> userIds) {
    if (userIds.isEmpty) return;
    _socket?.emit('presence:subscribe', {'userIds': userIds});
  }

  void unsubscribePresence(List<String> userIds) {
    if (userIds.isEmpty) return;
    _socket?.emit('presence:unsubscribe', {'userIds': userIds});
  }

  void joinConversation(String conversationId) =>
      _socket?.emit('conversation:join', {'conversationId': conversationId});

  void leaveConversation(String conversationId) =>
      _socket?.emit('conversation:leave', {'conversationId': conversationId});

  /// [clientId] is a locally generated uuid so the optimistic bubble the UI
  /// already shows can be matched against the ack that comes back, instead
  /// of appearing twice.
  void send(
      {required String conversationId,
      required String text,
      required String clientId}) {
    _socket?.emit('message:send',
        {'conversationId': conversationId, 'text': text, 'clientId': clientId});
  }

  void setTyping({required String conversationId, required bool isTyping}) {
    _socket?.emit('typing:update',
        {'conversationId': conversationId, 'isTyping': isTyping});
  }

  void markRead(String conversationId) =>
      _socket?.emit('message:read', {'conversationId': conversationId});

  void dispose() {
    _socket?.dispose();
    _newMessageController.close();
    _ackController.close();
    _typingController.close();
    _readController.close();
    _connectionController.close();
    _threadUpdateController.close();
    _presenceChangedController.close();
    _presenceSnapshotController.close();
  }
}

/// Built once per app session. Doesn't rebuild on every token refresh
/// (unlike Dio's per-request header, a socket is a standing connection) —
/// call reconnectWithFreshToken() explicitly after login/logout instead of
/// relying on this provider to notice a token change.
final chatSocketProvider = Provider<ChatSocketService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final service = ChatSocketService(storage);
  service.connect();
  ref.onDispose(service.dispose);
  return service;
});
