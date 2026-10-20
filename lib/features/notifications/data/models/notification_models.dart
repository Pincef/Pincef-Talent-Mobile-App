import 'package:flutter/material.dart';
import 'package:talentbridge/core/theme/app_theme.dart';

enum NotificationCategory {
  applications,
  assessments,
  interviews,
  jobs,
  system,
  messages,
  other
}

extension NotificationCategoryLabel on NotificationCategory {
  String get label => switch (this) {
        NotificationCategory.applications => 'Candidates',
        NotificationCategory.assessments => 'Assessments',
        NotificationCategory.interviews => 'Interviews',
        NotificationCategory.jobs => 'Jobs',
        NotificationCategory.system => 'System',
        NotificationCategory.messages => 'Messages',
        NotificationCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        NotificationCategory.applications => Icons.person_add_alt_1_outlined,
        NotificationCategory.assessments => Icons.assignment_outlined,
        NotificationCategory.interviews => Icons.videocam_outlined,
        NotificationCategory.jobs => Icons.work_outline,
        NotificationCategory.system => Icons.info_outline,
        NotificationCategory.messages => Icons.chat_bubble_outline,
        NotificationCategory.other => Icons.notifications_none,
      };

  Color get color => switch (this) {
        NotificationCategory.applications => const Color(0xFF3478F6),
        NotificationCategory.assessments => const Color(0xFF3478F6),
        NotificationCategory.interviews => AppColors.statusMatchGreen,
        NotificationCategory.jobs => AppColors.orange,
        NotificationCategory.system => const Color(0xFF6376D9),
        NotificationCategory.messages => const Color(0xFF8A5CF6),
        NotificationCategory.other => AppColors.textSecondary,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.category,
    this.isRead = false,
    this.actionLabel,
    this.actionPath,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationCategory category;
  final bool isRead;
  final String? actionLabel;
  final String? actionPath;

  IconData get icon => category.icon;
  Color get color => category.color;
  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  String get timeLabel {
    final elapsed = DateTime.now().difference(createdAt);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24 && isToday) return '${elapsed.inHours}h ago';
    if (elapsed.inDays == 1) return 'Yesterday';
    if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString();
    final category = NotificationCategory.values.firstWhere(
      (value) => value.name == rawCategory,
      orElse: () => NotificationCategory.other,
    );
    return AppNotification(
      id: (json['_id'] ?? json['id']).toString(),
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      category: category,
      isRead: json['readAt'] != null,
      actionLabel: json['actionLabel']?.toString(),
      actionPath: json['actionPath']?.toString(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        createdAt: createdAt,
        category: category,
        isRead: isRead ?? this.isRead,
        actionLabel: actionLabel,
        actionPath: actionPath,
      );
}
