/// lib/features/profile/data/models/activity_item.dart
///
/// Mirrors an entry from GET /api/users/me/activity — this endpoint
/// doesn't exist on the backend yet (see activity.model.ts /
/// activity.service.ts proposal); this screen is written against the
/// shape that endpoint is meant to return so it's ready once it does.
class ActivityItem {
  final String id;
  final String message; // pre-rendered by the backend, e.g. "Moved Sarah
  // Jenkins to Final Interview for Senior UX Designer"
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: (json['_id'] ?? json['id']) as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Matches the mockup's relative timestamps ("14 minutes ago").
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

/// One page of the cursor-paginated activity list.
class ActivityPage {
  final List<ActivityItem> items;
  final String? nextCursor; // null means there's nothing more to load

  const ActivityPage({required this.items, this.nextCursor});
}
