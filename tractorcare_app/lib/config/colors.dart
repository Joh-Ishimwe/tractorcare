// lib/config/colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF4CAF50);       // Green
  static const Color primaryDark = Color(0xFF388E3C);
  static const Color primaryLight = Color(0xFF81C784);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF764BA2);     // Purple
  static const Color secondaryDark = Color(0xFF5E3A82);
  static const Color secondaryLight = Color(0xFF9B6BC4);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);       // Light Green
  static const Color warning = Color(0xFFF59E0B);       // Orange
  static const Color error = Color(0xFFEF4444);         // Red
  static const Color info = Color(0xFF3B82F6);          // Blue
  
  // Neutral Colors
  static const Color background = Color(0xFFF8F9FF);    // Light Blue-ish
  static const Color surface = Color(0xFFFFFFFF);       // White
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Light Gray
  
  // Text Colors
  static const Color textPrimary = Color(0xFF333333);   // Dark Gray
  static const Color textSecondary = Color(0xFF666666); // Medium Gray
  static const Color textTertiary = Color(0xFF999999);  // Light Gray
  static const Color textDisabled = Color(0xFFCCCCCC);  // Very Light Gray
  
  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color borderDark = Color(0xFFBDBDBD);
  
  // Tractor Status Colors
  static const Color statusGood = Color(0xFF10B981);    // Green
  static const Color statusWarning = Color(0xFFF59E0B); // Orange
  static const Color statusCritical = Color(0xFFEF4444); // Red
  static const Color statusUnknown = Color(0xFF999999); // Gray
  
  // Audio Status Colors
  static const Color audioNormal = Color(0xFF10B981);   // Green
  static const Color audioMinor = Color(0xFFF59E0B);    // Orange
  static const Color audioWarning = Color(0xFFFF6B35); // Orange-Red
  static const Color audioCritical = Color(0xFFEF4444); // Red
  
  // Maintenance Status Colors
  static const Color maintenanceUpcoming = Color(0xFFFBBF24); // Yellow
  static const Color maintenanceDue = Color(0xFFF59E0B);      // Orange
  static const Color maintenanceOverdue = Color(0xFFEF4444);  // Red
  static const Color maintenanceCompleted = Color(0xFF10B981); // Green
  
  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF4CAF50),
    Color(0xFF66BB6A),
  ];
  
  static const List<Color> successGradient = [
    Color(0xFF10B981),
    Color(0xFF34D399),
  ];
  
  static const List<Color> warningGradient = [
    Color(0xFFF59E0B),
    Color(0xFFFBBF24),
  ];
  
  static const List<Color> errorGradient = [
    Color(0xFFEF4444),
    Color(0xFFF87171),
  ];
  
  // Shadow Colors
  static Color shadow = Colors.black.withOpacity(0.1);
  static Color shadowLight = Colors.black.withOpacity(0.05);
  static Color shadowDark = Colors.black.withOpacity(0.15);
  
  // Overlay Colors
  static Color overlay = Colors.black.withOpacity(0.5);
  static Color overlayLight = Colors.black.withOpacity(0.3);
  static Color overlayDark = Colors.black.withOpacity(0.7);
  
  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
  ];
  
  static const Color gradientStart = Color(0xFF4CAF50); // Green, example primary gradient start
  static const Color gradientEnd = Color(0xFF2196F3); // Blue, example gradient end
  static const Color textOnPrimary = Colors.white;
  static const Color surfaceElevated = Color(0xFFF6F9FC);
  
  // Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
      case 'normal':
      case 'completed':
        return statusGood;
      case 'warning':
      case 'due':
        return statusWarning;
      case 'critical':
      case 'overdue':
        return statusCritical;
      default:
        return statusUnknown;
    }
  }
  
  // Get audio severity color
  static Color getAudioSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return audioNormal;
      case 'medium':
        return audioMinor;
      case 'high':
        return audioWarning;
      case 'critical':
        return audioCritical;
      default:
        return statusUnknown;
    }
  }
  
  // Get maintenance status color
  static Color getMaintenanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return maintenanceUpcoming;
      case 'due':
        return maintenanceDue;
      case 'overdue':
        return maintenanceOverdue;
      case 'completed':
        return maintenanceCompleted;
      default:
        return statusUnknown;
    }
  }
}