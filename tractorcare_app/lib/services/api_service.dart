// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import '../models/user.dart';
import '../models/tractor.dart';
import '../models/maintenance_alert.dart';
import '../models/prediction_result.dart';



class ApiService {
  static String get baseUrl => Environment.apiBaseUrl;
  static Duration get timeout => Environment.apiTimeout;

  Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ============================================================================
  // AUTHENTICATION ENDPOINTS
  // ============================================================================

  /// Register new user
  Future<Map<String, dynamic>> register(User user, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _getHeaders(),
            body: jsonEncode({
              'email': user.email,
              'password': password,
              'full_name': user.name,
              'phone': user.phone,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  /// Login user
Future<Map<String, dynamic>> login(String email, String password) async {
  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: _getHeaders(),
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Invalid credentials');
    } else {
      throw Exception('Login failed: ${response.statusCode} - ${response.body}');
    }
  } on SocketException {
    throw Exception('No internet connection');
  } on TimeoutException {
    throw Exception('Connection timeout. Server may be starting up (30-60s)...');
  } catch (e) {
    throw Exception('Login failed: ${e.toString().replaceAll('Exception: ', '')}');
  }
}

  /// Get current user
  Future<User> getCurrentUser(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/me'),
            headers: _getHeaders(token: token),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load user profile');
      }
    } catch (e) {
      throw Exception('Error loading profile: $e');
    }
  }

  // ============================================================================
  // TRACTOR ENDPOINTS
  // ============================================================================

  /// Get all tractors for current user
  Future<List<Tractor>> getTractors(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/tractors/'),
            headers: _getHeaders(token: token),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Tractor.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tractors');
      }
    } catch (e) {
      throw Exception('Error loading tractors: $e');
    }
  }

  /// Get single tractor by ID
  Future<Tractor> getTractor(String token, String tractorId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/tractors/$tractorId'),
            headers: _getHeaders(token: token),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Tractor.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load tractor');
      }
    } catch (e) {
      throw Exception('Error loading tractor: $e');
    }
  }

  /// Create new tractor
  Future<Tractor> createTractor(String token, Tractor tractor) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tractors/'),
            headers: _getHeaders(token: token),
            body: jsonEncode(tractor.toJson()),
          )
          .timeout(timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Tractor.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to create tractor');
      }
    } catch (e) {
      throw Exception('Error creating tractor: $e');
    }
  }

  /// Update tractor
  Future<Tractor> updateTractor(String token, String tractorId, Tractor tractor) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/tractors/$tractorId'),
            headers: _getHeaders(token: token),
            body: jsonEncode(tractor.toJson()),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Tractor.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update tractor');
      }
    } catch (e) {
      throw Exception('Error updating tractor: $e');
    }
  }

  /// Delete tractor
  Future<void> deleteTractor(String token, String tractorId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/tractors/$tractorId'),
            headers: _getHeaders(token: token),
          )
          .timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete tractor');
      }
    } catch (e) {
      throw Exception('Error deleting tractor: $e');
    }
  }

  // ============================================================================
  // MAINTENANCE ALERTS ENDPOINTS
  // ============================================================================

  /// Get all alerts for a tractor
  Future<List<MaintenanceAlert>> getAlerts(String token, String tractorId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/maintenance/$tractorId/alerts'),
            headers: _getHeaders(token: token),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MaintenanceAlert.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load alerts');
      }
    } catch (e) {
      throw Exception('Error loading alerts: $e');
    }
  }

  /// Get all alerts for all user's tractors
  Future<List<MaintenanceAlert>> getAllUserAlerts(String token) async {
    try {
      // First get all tractors
      final tractors = await getTractors(token);
      
      if (tractors.isEmpty) {
        return []; // No tractors, no alerts
      }
      
      // Fetch alerts for each tractor
      final allAlerts = <MaintenanceAlert>[];
      for (final tractor in tractors) {
        try {
          // Use tractor_id if available, otherwise fall back to id
          final tractorIdentifier = tractor.tractorId ?? tractor.id;
          final tractorAlerts = await getAlerts(token, tractorIdentifier);
          allAlerts.addAll(tractorAlerts);
        } catch (e) {
          print('Error loading alerts for tractor ${tractor.tractorId ?? tractor.id}: $e');
          // Continue with other tractors even if one fails
        }
      }
      
      return allAlerts;
    } catch (e) {
      throw Exception('Error loading alerts: $e');
    }
  }

  // ============================================================================
  // PREDICTION ENDPOINTS
  // ============================================================================

  /// Rule-based prediction
  Future<PredictionResult> predictRuleBased(
    String token,
    String tractorId,
    double engineHours,
    String usageIntensity,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/predict/rule-based'),
            headers: _getHeaders(token: token),
            body: jsonEncode({
              'tractor_id': tractorId,
              'engine_hours': engineHours,
              'usage_intensity': usageIntensity,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Prediction failed');
      }
    } catch (e) {
      throw Exception('Error making prediction: $e');
    }
  }

  /// ML audio-based prediction
  Future<PredictionResult> predictMLAudio(
    String token,
    String tractorId,
    File audioFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict/ml-audio'),
      );

      request.headers.addAll(_getHeaders(token: token));
      request.fields['tractor_id'] = tractorId;
      request.files.add(
        await http.MultipartFile.fromPath('audio_file', audioFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2), // Longer timeout for file upload
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Audio prediction failed');
      }
    } catch (e) {
      throw Exception('Error with audio prediction: $e');
    }
  }

  /// Combined prediction (rule-based + ML)
  Future<PredictionResult> predictCombined(
    String token,
    String tractorId,
    double engineHours,
    String usageIntensity,
    File? audioFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict/combined'),
      );

      request.headers.addAll(_getHeaders(token: token));
      request.fields['tractor_id'] = tractorId;
      request.fields['engine_hours'] = engineHours.toString();
      request.fields['usage_intensity'] = usageIntensity;

      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio_file', audioFile.path),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Combined prediction failed');
      }
    } catch (e) {
      throw Exception('Error with combined prediction: $e');
    }
  }

  // ============================================================================
  // UTILITY ENDPOINTS
  // ============================================================================

  /// Health check
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get API version
  Future<String> getVersion() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['version'] ?? '1.0.0';
      }
      return '1.0.0';
    } catch (e) {
      return '1.0.0';
    }
  }
}
