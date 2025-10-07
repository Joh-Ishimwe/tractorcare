class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String tractors = '/tractors';
  static const String bookings = '/bookings';
  static const String predictions = '/predict/rule-based';
  static const String mlAudio = '/predict/ml-audio';
  static const String sync = '/sync';
  
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}