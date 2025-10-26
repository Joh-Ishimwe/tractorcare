// lib/config/environment.dart

class Environment {
  //  PRODUCTION -  deployed Render backend
  static const String productionUrl = 'https://tractorcare-backend.onrender.com';
  
  //  DEVELOPMENT - Local backend URLs
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000';
  static const String iosSimulatorUrl = 'http://localhost:8000';
  
  // Current API base URL (CHANGE THIS to switch environments)
  static const String apiBaseUrl = productionUrl;  // Using production!
  
  static const bool isProduction = true;
  static const bool enableDebugLogs = false;
  // Shorter timeout so the app fails fast when backend is unreachable
  static const Duration apiTimeout = Duration(seconds: 10);
  
  static String getEndpoint(String path) {
    return '$apiBaseUrl$path';
  }
}
