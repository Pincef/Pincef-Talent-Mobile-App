import 'package:flutter/material.dart';
import 'brand_color.dart';

const authLabelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: BrandColors.muted,
  letterSpacing: 0.4,
);

/// Bordered input decoration matching the auth-screen mockups (thin
/// grey border, orange on focus, red on error, optional leading icon
/// and trailing widget for show/hide-password toggles).
InputDecoration authInputDecoration({required String hint, IconData? icon, Widget? suffix}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13.5, color: BrandColors.navy),
    prefixIcon: icon != null ? Icon(icon, size: 18, color: BrandColors.navy) : null,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    isDense: true,
    border: border(BrandColors.border),
    enabledBorder: border(BrandColors.border),
    focusedBorder: border(BrandColors.orange),
    errorBorder: border(Colors.red.shade300),
    filled: true,
    fillColor: Colors.white,
  );
}

/// Shared validator — was copy-pasted identically into sign_up_screen.dart,
/// login_screen.dart, and forgot_password_screen.dart.
String? emailValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Email is required';
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
  return null;
}