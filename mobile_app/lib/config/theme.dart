import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF2D5016);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color warningYellow = Color(0xFFFFA500);
  static const Color criticalRed = Color(0xFFDC3545);
  static const Color successGreen = Color(0xFF28A745);
  static const Color neutralGray = Color(0xFF6C757D);
  static const Color lightGray = Color(0xFFF8F9FA);
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: accentOrange,
      error: criticalRed,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
  
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
      case 'good':
      case 'available':
        return successGreen;
      case 'warning':
      case 'due_soon':
        return warningYellow;
      case 'critical':
      case 'overdue':
      case 'broken':
        return criticalRed;
      case 'maintenance':
      case 'in_use':
        return accentOrange;
      default:
        return neutralGray;
    }
  }
}