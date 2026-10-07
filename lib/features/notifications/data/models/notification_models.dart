import 'package:flutter/material.dart';

enum NotificationCategory { jobMatches, applications, messages }

extension NotificationCategoryLabel on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.jobMatches:
        return 'Job Matches';
      case NotificationCategory.applications:
        return 'Applications';
      case NotificationCategory.messages:
        return 'Messages';
    }
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.category,
    required this.icon,
    required this.color,
    required this.isToday,
    this.isRead = false,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String message;
  final String timeLabel;
  final NotificationCategory category;
  final IconData icon;
  final Color color;
  final bool isToday;
  final bool isRead;
  final String? actionLabel;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        message: message,
        timeLabel: timeLabel,
        category: category,
        icon: icon,
        color: color,
        isToday: isToday,
        isRead: isRead ?? this.isRead,
        actionLabel: actionLabel,
      );
}
