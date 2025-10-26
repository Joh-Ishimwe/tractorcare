// lib/config/constants.dart

class AppConstants {
  // App Info
  static const String appName = 'TractorCare';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Smart maintenance for smart farming';

  // API Configuration
  static const Duration apiTimeout = Duration(seconds: 10);
  static const Duration uploadTimeout = Duration(minutes: 1);
  static const int maxRetries = 3;

  // Audio Recording
  static const int audioRecordingDuration = 10; 
  static const int audioSampleRate = 44100;
  static const String audioFormat = 'm4a';

  // Tractor Usage Intensities
  static const List<String> usageIntensities = [
    'light',
    'moderate',
    'heavy',
  ];

  static const Map<String, String> usageIntensityLabels = {
    'light': 'Light Usage',
    'moderate': 'Moderate Usage',
    'heavy': 'Heavy Usage',
  };

  // User Roles
  static const List<String> userRoles = [
    'farmer',
    'mechanic',
    'cooperative_manager',
  ];

  static const Map<String, String> userRoleLabels = {
    'farmer': 'Farmer',
    'mechanic': 'Mechanic',
    'cooperative_manager': 'Cooperative Manager',
  };

  // Alert Priorities
  static const List<String> alertPriorities = [
    'critical',
    'high',
    'medium',
    'low',
  ];

  // Alert Statuses
  static const List<String> alertStatuses = [
    'pending',
    'in_progress',
    'completed',
    'overdue',
    'cancelled',
  ];

  // Maintenance Types
  static const List<String> maintenanceTypes = [
    'oil_change',
    'filter_replace',
    'inspection',
    'repair',
    'service',
  ];

  static const Map<String, String> maintenanceTypeLabels = {
    'oil_change': 'Oil Change',
    'filter_replace': 'Filter Replacement',
    'inspection': 'Inspection',
    'repair': 'Repair',
    'service': 'General Service',
  };

  // Severity Levels
  static const List<String> severityLevels = [
    'critical',
    'high',
    'medium',
    'low',
    'normal',
  ];

  // Validation
  static const int minPasswordLength = 6;
  static const int minPhoneLength = 10;
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Storage Keys
  static const String storageKeyToken = 'auth_token';
  static const String storageKeyUser = 'current_user';
  static const String storageKeyTractors = 'tractors_cache';
  static const String storageKeyAlerts = 'alerts_cache';
  static const String storageKeyLastSync = 'last_sync_time';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration userCacheDuration = Duration(hours: 24);

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Error Messages
  static const String errorNetworkUnavailable = 'No internet connection';
  static const String errorServerUnavailable = 'Server is unavailable';
  static const String errorUnauthorized = 'Session expired. Please login again';
  static const String errorUnknown = 'An error occurred. Please try again';

  // Success Messages
  static const String successLogin = 'Login successful';
  static const String successRegister = 'Registration successful';
  static const String successTractorCreated = 'Tractor added successfully';
  static const String successTractorUpdated = 'Tractor updated successfully';
  static const String successTractorDeleted = 'Tractor deleted successfully';

  // Currency
  static const String currency = 'RWF';
  static const String currencySymbol = 'RWF';

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayTimeFormat = 'HH:mm';

  // Feature Flags
  static const bool enableOfflineMode = false;
  static const bool enablePushNotifications = false;
  static const bool enableAnalytics = true;
  static const bool enableDebugMode = false;

  // Links
  static const String helpUrl = 'https://tractorcare.com/help';
  static const String privacyPolicyUrl = 'https://tractorcare.com/privacy';
  static const String termsOfServiceUrl = 'https://tractorcare.com/terms';
  static const String supportEmail = 'support@tractorcare.com';

  // API Endpoints (relative to base URL)
  static const String endpointHealth = '/health';
  static const String endpointLogin = '/auth/login';
  static const String endpointRegister = '/auth/register';
  static const String endpointCurrentUser = '/auth/me';
  static const String endpointTractors = '/tractors/';
  static const String endpointAlerts = '/alerts/';
  static const String endpointPredictRuleBased = '/predict/rule-based';
  static const String endpointPredictMLAudio = '/predict/ml-audio';
  static const String endpointPredictCombined = '/predict/combined';
}
