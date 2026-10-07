import 'package:dio/dio.dart';
import '../../../../core/network/api_exception.dart';

class CandidateChatContact {
  const CandidateChatContact({
    required this.id, // == conversationId
    required this.partnerId, // the recruiter's raw user id — used for presence subscribe
    required this.name,
    required this.company,
    required this.preview,
    required this.time,
    this.unreadCount = 0,
  });

  final String id;
  final String partnerId;
  final String name;
  final String company;
  final String preview;
  final String time;
  final int unreadCount;

  bool get unread => unreadCount > 0;

  CandidateChatContact copyWith(
          {String? preview, String? time, int? unreadCount}) =>
      CandidateChatContact(
        id: id,
        partnerId: partnerId,
        name: name,
        company: company,
        preview: preview ?? this.preview,
        time: time ?? this.time,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  factory CandidateChatContact.fromJson(Map<String, dynamic> json) {
    final recruiter = json['recruiterId'] as Map<String, dynamic>?;
    final company = json['companyId'] as Map<String, dynamic>?;
    return CandidateChatContact(
      id: json['_id'] as String,
      partnerId: (recruiter?['_id'] ?? recruiter?['id'] ?? '') as String,
      name: recruiter == null
          ? 'Recruiter'
          : '${recruiter['firstName'] ?? ''} ${recruiter['lastName'] ?? ''}'
              .trim(),
      company: company?['name'] as String? ?? '',
      preview: json['lastMessagePreview'] as String? ?? '',
      time: json['lastMessageAt'] as String? ?? '',
      unreadCount: (json['unreadForCandidate'] as num? ?? 0).toInt(),
    );
  }
}

/// Reuses ChatMessage from messages_repository.dart — the message shape on
/// the wire is identical for both sides of a conversation.
class CandidateMessagesRepository {
  CandidateMessagesRepository(this._dio);

  final Dio _dio;

  Future<List<CandidateChatContact>> getContacts() async {
    try {
      final res = await _dio.get('/messaging/threads');
      return (res.data['threads'] as List)
          .map((t) => CandidateChatContact.fromJson(t as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
