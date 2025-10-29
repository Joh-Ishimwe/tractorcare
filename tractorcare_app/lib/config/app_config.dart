// lib/config/app_config.dart

class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'https://tractorcare-backend.onrender.com';
  static const String apiVersion = 'v1';
  
  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String tractorsEndpoint = '/tractors';
  static const String audioEndpoint = '/audio';
  static const String baselineEndpoint = '/baseline';
  static const String maintenanceEndpoint = '/maintenance';
  static const String statisticsEndpoint = '/statistics';
  static const String demoEndpoint = '/demo';
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String rememberMeKey = 'remember_me';
  
  // App Configuration
  static const String appName = 'TractorCare';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  
  // Audio Configuration
  static const int maxAudioDuration = 30; // seconds
  static const int minAudioDuration = 5; // seconds
  static const int sampleRate = 16000; // Hz
  static const int maxFileSizeMB = 10;
  
  // Baseline Configuration
  static const int baselineSamplesRequired = 5;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Timeouts
  static const int apiTimeout = 30; // seconds
  static const int uploadTimeout = 60; // seconds
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  // Get full API URL
  static String getApiUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }
  
  // Get auth headers
  static Map<String, String> getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Get multipart headers
  static Map<String, String> getMultipartHeaders({String? token}) {
    final headers = {
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Environment check
  static bool get isProduction => apiBaseUrl.contains('onrender.com');
  static bool get isDevelopment => !isProduction;
  
  // Debug mode
  static bool get debugMode => isDevelopment;
  
  // Logging
  static void log(String message) {
    if (debugMode) {
      print('🚜 TractorCare: $message');
    }
  }
  
  static void logError(String message, [dynamic error]) {
    if (debugMode) {
      print('❌ TractorCare Error: $message');
      if (error != null) {
        print('   Details: $error');
      }
    }
  }
  
  static void logSuccess(String message) {
    if (debugMode) {
      print('✅ TractorCare: $message');
    }
  }
}