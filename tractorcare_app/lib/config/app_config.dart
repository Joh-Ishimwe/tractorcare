class AppConfig {
  static const String apiBaseUrl = 'https://tractorcare-backend.onrender.com';
  
  static const String authEndpoint = '/auth';
  static const String tractorsEndpoint = '/tractors';
  static const String audioEndpoint = '/audio';
  static const String baselineEndpoint = '/baseline';
  static const String maintenanceEndpoint = '/maintenance';
  static const String statisticsEndpoint = '/statistics';
  static const String demoEndpoint = '/demo';
  
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String rememberMeKey = 'remember_me';
  
  static const String appName = 'TractorCare';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  
  static const int maxAudioDuration = 30;
  static const int minAudioDuration = 5;
  static const int sampleRate = 16000;
  static const int maxFileSizeMB = 10;
  
  static const int baselineSamplesRequired = 5;
  
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  static const int apiTimeout = 30;
  static const int uploadTimeout = 60;
  
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  
  static String getApiUrl(String endpoint) {
    return '$apiBaseUrl$endpoint';
  }
  
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
  
  static Map<String, String> getMultipartHeaders({String? token}) {
    final headers = {
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  static bool get isProduction => apiBaseUrl.contains('onrender.com');
  static bool get isDevelopment => !isProduction;
  
  static bool get debugMode => isDevelopment;
  
  static String get apiStatus {
    return isProduction ? '🌐 LIVE API ($apiBaseUrl)' : '🔧 DEV API ($apiBaseUrl)';
  }
  
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
  
  static void initialize() {
    log('=== TRACTORCARE APP STARTING ===');
    log(apiStatus);
    log('Debug Mode: $debugMode');
    log('====================================');
  }
}