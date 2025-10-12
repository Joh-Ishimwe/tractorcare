import 'package:flutter/material.dart';

// App color palette (provided by user)
class AppColors {
  // Primary / Accent - Green
  static const Color primary = Color(0xFF22C55E); // #22C55E

  // Semantic
  static const Color success = Color(0xFF22C55E); // same as primary
  static const Color warning = Color(0xFFF59E0B); // #F59E0B
  static const Color error = Color(0xFFEF4444); // #EF4444
  static const Color info = Color(0xFF3B82F6); // #3B82F6
}

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  primaryColor: AppColors.primary,
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
    ),
  ),
);
