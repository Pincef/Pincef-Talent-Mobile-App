/// lib/features/settings/data/models/security_log_item.dart
///
/// Mirrors an entry from GET /api/users/me/security-logs.
class SecurityLogItem {
  final String id;
  final String
      type; // e.g. "login_success", "login_failed" — matches SecurityEventType on the backend
  final String message;
  final DateTime createdAt;

  const SecurityLogItem({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  factory SecurityLogItem.fromJson(Map<String, dynamic> json) {
    return SecurityLogItem(
      id: (json['_id'] ?? json['id']) as String,
      type: json['type'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  bool get isWarning => type == 'login_failed';

  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

class SecurityLogPage {
  final List<SecurityLogItem> items;
  final String? nextCursor;

  const SecurityLogPage({required this.items, this.nextCursor});
}
