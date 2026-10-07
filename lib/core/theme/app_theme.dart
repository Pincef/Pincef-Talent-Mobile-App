import 'package:flutter/material.dart';
import 'brand_color.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'Roboto',
  colorScheme: const ColorScheme.light(
    primary: BrandColors.orange,
    secondary: BrandColors.navy,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: BrandColors.navy,
  ),
  scaffoldBackgroundColor: BrandColors.background,
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: BrandColors.navy,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: BrandColors.navy,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BrandColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandColors.orange, width: 2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: BrandColors.orange,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
);

class AppColors {
  AppColors._();

  static const navy = Color(0xFF0E1A3D);
  static const navyLight = Color(0xFF16224A);
  static const orange = Color(0xFFF4801F);
  static const peach = Color(0xFFFBE3D0);
  static const peachBorder = Color(0xFFF3CBA5);

  static const textPrimary = Color(0xFF1A1F36);
  static const textSecondary = Color(0xFF6B7280);
  static const divider = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF7F8FA);

  static const statusInterviewing = Color(0xFFF4801F);
  static const statusApplicationSent = Color(0xFF2F6FED);
  static const statusMatchGreen = Color(0xFF1AAE5C);
  static const statusParsing = Color(0xFFF4801F);
  static const statusReady = Color(0xFF1AAE5C);
}

// final ThemeData appTheme = ThemeData(
//   useMaterial3: true,
//   scaffoldBackgroundColor: AppColors.surface,
//   colorScheme: ColorScheme.fromSeed(
//     seedColor: AppColors.orange,
//     primary: AppColors.orange,
//   ),
//   fontFamily: 'Roboto',
//   dividerColor: AppColors.divider,
//   cardTheme: CardThemeData(
//     color: Colors.white,
//     elevation: 0,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(12),
//       side: const BorderSide(color: AppColors.divider),
//     ),
//   ),
//   inputDecorationTheme: const InputDecorationTheme(
//     border: OutlineInputBorder(),
//   ),
// );
