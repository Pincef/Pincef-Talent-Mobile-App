import 'package:flutter/material.dart';

/// Single source of truth for the TalentBridge brand palette.
/// Previously duplicated as private consts in welcome_screen.dart,
/// sign_up_screen.dart, login_screen.dart, and forgot_password_screen.dart.
class BrandColors {
  BrandColors._();

  static const navy = Color(0xFF1B2A4E);
  static const orange = Color(0xFFF5821F);
  static const gradient = LinearGradient(
    colors: [Color(0xFFE0E3E8), Color(0xFFF7F3F3)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );
  static const background = Color(0xFFF5F6FA);
  static const border = Color(0xFFE7E9EF);
  static const muted = Color(0xFF6B7280);
  static const iconBg = Color(0xFFF3F4F6);
}
