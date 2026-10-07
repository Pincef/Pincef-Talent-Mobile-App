import 'package:dio/dio.dart';
import '../../../../core/network/api_exception.dart';

enum MessageStatus { sent, delivered, read }

class MessageThread {
  const MessageThread({
    required this.id, // == conversationId, used to join the socket room
    required this.partnerId, // the candidate's raw user id — used for presence subscribe
    required this.name,
    required this.role,
    required this.preview,
    required this.time,
    required this.status,
    this.unreadCount = 0,
  });

  final String id;
  final String partnerId;
  final String name;
  final String role;
  final String preview;
  final String time;
  final String status;
  final int unreadCount;

  bool get unread => unreadCount > 0;

  MessageThread copyWith({String? preview, String? time, int? unreadCount}) =>
      MessageThread(
        id: id,
        partnerId: partnerId,
        name: name,
        role: role,
        preview: preview ?? this.preview,
        time: time ?? this.time,
        status: status,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final candidate = json['candidateId'] as Map<String, dynamic>?;
    final job = json['jobId'] as Map<String, dynamic>?;
    return MessageThread(
      id: json['_id'] as String,
      partnerId: (candidate?['_id'] ?? candidate?['id'] ?? '') as String,
      name: candidate == null
          ? 'Unknown'
          : '${candidate['firstName'] ?? ''} ${candidate['lastName'] ?? ''}'
              .trim(),
      role: job?['title'] as String? ?? '',
      preview: json['lastMessagePreview'] as String? ?? '',
      time: json['lastMessageAt'] as String? ?? '',
      status:
          'New', // TODO: map from application pipeline stage once that's exposed here
      unreadCount: (json['unreadForRecruiter'] as num? ?? 0).toInt(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.time,
    this.isMine = false,
    this.status,
    this.clientId,
  });

  final String id;
  final String text;
  final String time;
  final bool isMine;
  final MessageStatus? status;
  // Present only on messages this client itself sent optimistically, before
  // the server ack arrives — lets the notifier find-and-replace instead of
  // appending a duplicate.
  final String? clientId;

  factory ChatMessage.fromJson(Map<String, dynamic> json,
      {required String myUserId}) {
    return ChatMessage(
      id: json['id'] as String? ?? json['_id'] as String,
      text: json['text'] as String,
      time: json['createdAt'] as String,
      isMine: json['senderId'] == myUserId,
      status: _statusFromString(json['status'] as String?),
      clientId: json['clientId'] as String?,
    );
  }

  static MessageStatus? _statusFromString(String? value) {
    switch (value) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return null;
    }
  }
}

/// Talks to the REST fallback endpoints in messaging.controller.ts, using
/// the app's shared Dio instance — the auth interceptor already attaches
/// the access token and handles a 401 refresh-and-retry, so this class
/// never touches tokens directly.
/// Live updates arrive over the socket (see messages_provider.dart) — this
/// repository only covers the initial page load and the no-socket-yet
/// send fallback.
class MessagesRepository {
  MessagesRepository(this._dio);

  final Dio _dio;

  Future<List<MessageThread>> getThreads() async {
    try {
      final res = await _dio.get('/messaging/threads');
      return (res.data['threads'] as List)
          .map((t) => MessageThread.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<ChatMessage>> getConversation(
      String conversationId, String myUserId) async {
    try {
      final res =
          await _dio.get('/messaging/conversations/$conversationId/messages');
      return (res.data['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>,
              myUserId: myUserId))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Only used if the socket send in the notifier times out — normal sends
  /// go straight over the socket for lower latency.
  Future<ChatMessage> sendViaRest(String conversationId, String text,
      String clientId, String myUserId) async {
    try {
      final res = await _dio.post(
        '/messaging/conversations/$conversationId/messages',
        data: {'text': text, 'clientId': clientId},
      );
      return ChatMessage.fromJson(res.data['message'] as Map<String, dynamic>,
          myUserId: myUserId);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Backs the "Message" button on the Candidates list and AI Candidate
  /// Ranking screen — get-or-create, so tapping it again on the same
  /// applicant reopens the existing thread instead of creating a second one.
  Future<String> startConversationForApplication(String applicationId) async {
    try {
      final res = await _dio
          .post('/messaging/conversations/for-application/$applicationId');
      return res.data['conversationId'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post('/messaging/conversations/$conversationId/read');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
