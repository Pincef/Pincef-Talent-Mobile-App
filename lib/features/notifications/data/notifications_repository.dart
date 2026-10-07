import 'package:flutter/material.dart';
import 'package:talentbridge/core/theme/app_theme.dart';
import 'models/notification_models.dart';

/// Notification endpoints have not been introduced in the backend yet.
/// This repository keeps the UI contract stable and is the one place to
/// replace the seeded alerts with GET /notifications and PATCH read actions.
class NotificationsRepository {
  Future<List<AppNotification>> loadNotifications({required bool isRecruiter}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return isRecruiter ? _recruiterAlerts : _candidateAlerts;
  }

  Future<void> markAllAsRead() async {
    // TODO: PATCH /notifications/read-all when the API is available.
  }
}

const _candidateAlerts = [
  AppNotification(id: 'candidate-interview', title: 'Interview Scheduled', message: 'Your technical interview with Global Tech Corp for the Senior Product Designer role is confirmed for tomorrow at 2:00 PM.', timeLabel: '10:45 AM', category: NotificationCategory.applications, icon: Icons.calendar_month_outlined, color: AppColors.statusMatchGreen, isToday: true, actionLabel: 'View interview'),
  AppNotification(id: 'candidate-match', title: 'New 98% Job Match', message: 'We found a new position at Stripe that closely matches your Product Strategy and Rapid Prototyping skills.', timeLabel: '2 hours ago', category: NotificationCategory.jobMatches, icon: Icons.auto_awesome, color: AppColors.orange, isToday: true, actionLabel: 'View match'),
  AppNotification(id: 'candidate-status', title: 'Application Status Update', message: 'Your application for UI Engineer at InnovaSoft has moved to the Technical Review stage.', timeLabel: 'Yesterday, 4:15 PM', category: NotificationCategory.applications, icon: Icons.fact_check_outlined, color: Color(0xFF6376D9), isToday: false, isRead: true),
  AppNotification(id: 'candidate-profile', title: 'Profile Viewed', message: 'A recruiter from Netflix viewed your profile. They are currently hiring for Design Systems roles.', timeLabel: 'Yesterday, 11:30 AM', category: NotificationCategory.messages, icon: Icons.visibility_outlined, color: Color(0xFF6376D9), isToday: false, isRead: true),
];

const _recruiterAlerts = [
  AppNotification(id: 'recruiter-applicant', title: 'New Qualified Applicant', message: 'Maya Chen applied for Senior Product Designer and meets 92% of the role requirements.', timeLabel: '9:32 AM', category: NotificationCategory.applications, icon: Icons.person_add_alt_1_outlined, color: AppColors.statusMatchGreen, isToday: true, actionLabel: 'Review candidate'),
  AppNotification(id: 'recruiter-interview', title: 'Interview Response Received', message: 'Marcus Vogel accepted the interview invitation for Frontend Engineer.', timeLabel: '1 hour ago', category: NotificationCategory.messages, icon: Icons.mark_email_read_outlined, color: AppColors.orange, isToday: true, actionLabel: 'View schedule'),
  AppNotification(id: 'recruiter-job', title: 'Job Post Reaching More Talent', message: 'Your Data Analyst opening has appeared in 138 candidate searches this week.', timeLabel: 'Yesterday, 3:20 PM', category: NotificationCategory.jobMatches, icon: Icons.trending_up_outlined, color: Color(0xFF6376D9), isToday: false, isRead: true),
  AppNotification(id: 'recruiter-report', title: 'Weekly Hiring Report Ready', message: 'Your weekly recruitment funnel summary is ready to review.', timeLabel: 'Yesterday, 9:00 AM', category: NotificationCategory.messages, icon: Icons.assessment_outlined, color: Color(0xFF6376D9), isToday: false, isRead: true, actionLabel: 'Open report'),
];
