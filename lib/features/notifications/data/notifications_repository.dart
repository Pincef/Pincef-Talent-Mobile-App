import 'package:dio/dio.dart';
import 'models/notification_models.dart';

class NotificationPage {
  const NotificationPage(
      {required this.items,
      required this.total,
      required this.unreadCount,
      required this.hasMore});
  final List<AppNotification> items;
  final int total;
  final int unreadCount;
  final bool hasMore;
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<NotificationPage> loadNotifications(
      {int page = 1, int limit = 20}) async {
    final response = await _dio
        .get('/notifications', queryParameters: {'page': page, 'limit': limit});
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return NotificationPage(
      items: (data['items'] as List? ?? const [])
          .map((item) =>
              AppNotification.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      hasMore: data['hasMore'] == true,
    );
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/notifications/unread-count');
    return ((response.data['data'] as Map)['unreadCount'] as num?)?.toInt() ??
        0;
  }

  Future<void> markAllAsRead() async => _dio.patch('/notifications/read-all');
  Future<void> markAsRead(String id) async =>
      _dio.patch('/notifications/$id/read');
}
