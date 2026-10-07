import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/socket_service.dart';

class PresenceInfo {
  const PresenceInfo({required this.online, this.lastSeenAt});
  final bool online;
  final DateTime? lastSeenAt;

  /// For the conversation header — "Online" while connected, otherwise a
  /// relative "last seen" label, or nothing at all if we've never heard
  /// anything about this person yet (haven't subscribed, or they've never
  /// connected).
  String? get statusLabel {
    if (online) return 'Online';
    final seen = lastSeenAt;
    if (seen == null) return null;
    final diff = DateTime.now().difference(seen);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }
}

/// userId -> current presence. Shared by both the recruiter and candidate
/// messaging screens (and anywhere else that ends up wanting an online
/// dot) rather than duplicated per screen, since presence is inherently
/// global — the same person is online or not regardless of who's looking.
class PresenceNotifier extends StateNotifier<Map<String, PresenceInfo>> {
  PresenceNotifier(this._socket) : super(const {}) {
    _changedSub = _socket.onPresenceChanged.listen(_onChanged);
    _snapshotSub = _socket.onPresenceSnapshot.listen(_onSnapshot);
  }

  final ChatSocketService _socket;
  late final StreamSubscription _changedSub;
  late final StreamSubscription _snapshotSub;

  void subscribe(Iterable<String> userIds) {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    _socket.subscribePresence(ids);
  }

  void unsubscribe(Iterable<String> userIds) {
    final ids = userIds.where((id) => id.isNotEmpty).toSet().toList();
    _socket.unsubscribePresence(ids);
  }

  void _onChanged(Map<String, dynamic> event) {
    final userId = event['userId'] as String?;
    if (userId == null) return;
    state = {
      ...state,
      userId: PresenceInfo(
        online: event['online'] as bool? ?? false,
        lastSeenAt: _parseEpoch(event['lastSeenAt']),
      ),
    };
  }

  void _onSnapshot(List<dynamic> entries) {
    final updates = <String, PresenceInfo>{};
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      final userId = entry['userId'] as String?;
      if (userId == null) continue;
      updates[userId] = PresenceInfo(
        online: entry['online'] as bool? ?? false,
        lastSeenAt: _parseEpoch(entry['lastSeenAt']),
      );
    }
    if (updates.isEmpty) return;
    state = {...state, ...updates};
  }

  DateTime? _parseEpoch(dynamic value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch((value as num).toInt());

  @override
  void dispose() {
    _changedSub.cancel();
    _snapshotSub.cancel();
    super.dispose();
  }
}

/// autoDispose so a full logout/re-login (or just navigating away from
/// every messaging screen) drops old presence state instead of it lingering
/// — same reasoning as the other messaging providers.
final presenceProvider = StateNotifierProvider.autoDispose<PresenceNotifier,
    Map<String, PresenceInfo>>((ref) {
  return PresenceNotifier(ref.watch(chatSocketProvider));
});
