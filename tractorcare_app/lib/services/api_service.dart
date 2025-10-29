// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/tractor.dart';
import '../models/audio_prediction.dart';
import '../models/maintenance.dart';

class ApiService {
  final String baseUrl = AppConfig.apiBaseUrl;
  String? _token;

  // Set authentication token
  void setToken(String token) {
    _token = token;
  }

  // Clear token
  void clearToken() {
    _token = null;
  }

  // Get headers with authentication
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }

  // Handle API errors
  void _handleError(http.Response response) {
    final statusCode = response.statusCode;
    String message = 'An error occurred';

    try {
      final data = json.decode(response.body);
      message = data['detail'] ?? data['message'] ?? message;
    } catch (e) {
      message = 'Error: $statusCode';
    }

    throw ApiException(message, statusCode);
  }

  // ==================== AUTH ENDPOINTS ====================

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _getHeaders(includeAuth: false),
      body: json.encode(userData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      _handleError(response);
      return {};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      print('Login request URL: $uri');
      
      // Use JSON format as expected by the backend schema
      final body = json.encode({
        'email': email,
        'password': password,
      });
      
      print('Login request body: $body');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 60), // Increased timeout for cold start
        onTimeout: () {
          throw Exception('Connection timeout. Server might be waking up. Please try again in a few seconds.');
        },
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('Login error: ${response.statusCode} - ${response.body}');
        
        // If server is down (500 error), provide mock response for development
        if (response.statusCode == 500 && 
            (email == 'jishimwe24@gmail.com' || email == 'j.ishimwe3@alustudent.com')) {
          print('Server is down, using mock authentication for development');
          return {
            'access_token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
            'token_type': 'bearer'
          };
        }
        
        _handleError(response);
        return {};
      }
    } on http.ClientException catch (e) {
      print('ClientException: $e');
      
      // For development, allow offline mode with known emails
      if (email == 'jishimwe24@gmail.com' || email == 'j.ishimwe3@alustudent.com') {
        print('Network error, using mock authentication for development');
        return {
          'access_token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
          'token_type': 'bearer'
        };
      }
      
      throw Exception('Network error. Please check your internet connection or try again. The server might be waking up (this can take 30-60 seconds on first request).');
    } on FormatException catch (e) {
      print('FormatException: $e');
      throw Exception('Invalid response from server');
    } catch (e) {
      print('Login exception: $e');
      
      // For development, allow offline mode with known emails
      if (e.toString().contains('Failed to fetch') || e.toString().contains('Connection')) {
        if (email == 'jishimwe24@gmail.com' || email == 'j.ishimwe3@alustudent.com') {
          print('Cannot connect to server, using mock authentication for development');
          return {
            'access_token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
            'token_type': 'bearer'
          };
        }
        throw Exception('Cannot connect to server. Please wait a moment and try again. The server may be starting up.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('getCurrentUser error: ${response.statusCode} - ${response.body}');
        
        // If server is down, provide mock user data for development
        if (response.statusCode == 500 || response.statusCode >= 500) {
          print('Server is down, using mock user data for development');
          return {
            'id': 'mock_user_id',
            'email': _token?.contains('jishimwe24') == true ? 'jishimwe24@gmail.com' : 'j.ishimwe3@alustudent.com',
            'full_name': 'Jean De Dieu Ishimwe',
            'phone': '+250788123456',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          };
        }
        
        _handleError(response);
        return {};
      }
    } catch (e) {
      print('getCurrentUser exception: $e');
      // Return mock data if server is unreachable
      return {
        'id': 'mock_user_id',
        'email': 'jishimwe24@gmail.com',
        'full_name': 'Jean De Dieu Ishimwe',
        'phone': '+250788123456',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };
    }
  }

  // ==================== TRACTOR ENDPOINTS ====================

  Future<List<Tractor>> getTractors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tractors/'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tractor.fromJson(json)).toList();
      } else {
        print('getTractors error: ${response.statusCode} - ${response.body}');
        return _getMockTractors();
      }
    } catch (e) {
      print('getTractors exception: $e');
      return _getMockTractors();
    }
  }

  List<Tractor> _getMockTractors() {
    return [
      Tractor.fromJson({
        'id': 'tractor_001',
        'tractor_id': 'MF240_001',
        'user_id': 'mock_user_id',
        'model': 'MF 240',
        'engine_hours': 1250.5,
        'purchase_year': 2020,
        'notes': 'Primary field tractor',
        'is_active': true,
        'created_at': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'status': 'good',
        'last_check_date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'has_baseline': true,
      }),
      Tractor.fromJson({
        'id': 'tractor_002', 
        'tractor_id': 'MF375_002',
        'user_id': 'mock_user_id',
        'model': 'MF 375',
        'engine_hours': 2100.0,
        'purchase_year': 2019,
        'notes': 'Secondary tractor for heavy work',
        'is_active': true,
        'created_at': DateTime.now().subtract(const Duration(days: 500)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'status': 'warning',
        'last_check_date': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'has_baseline': false,
      }),
    ];
  }

  Future<Tractor> getTractor(String tractorId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tractors/$tractorId'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Tractor.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to load tractor');
    }
  }

  Future<Tractor> createTractor(Map<String, dynamic> tractorData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tractors/'),
      headers: _getHeaders(),
      body: json.encode(tractorData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Tractor.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to create tractor');
    }
  }

  Future<Tractor> updateTractor(
    String tractorId,
    Map<String, dynamic> tractorData,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tractors/$tractorId'),
      headers: _getHeaders(),
      body: json.encode(tractorData),
    );

    if (response.statusCode == 200) {
      return Tractor.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to update tractor');
    }
  }

  Future<void> deleteTractor(String tractorId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tractors/$tractorId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      _handleError(response);
    }
  }

  // ==================== AUDIO PREDICTION ENDPOINTS ====================

  Future<AudioPrediction> uploadAudio(
    File audioFile,
    String tractorId,
    double engineHours,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/audio/predict'),
    );

    // Add headers
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    // Add fields
    request.fields['tractor_id'] = tractorId;
    request.fields['engine_hours'] = engineHours.toString();

    // Add file
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio_file',
        audioFile.path,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return AudioPrediction.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to upload audio');
    }
  }

  Future<List<AudioPrediction>> getPredictions({
    String? tractorId,
    int limit = 10,
  }) async {
    String url = '$baseUrl/audio/predictions?limit=$limit';
    if (tractorId != null) {
      url += '&tractor_id=$tractorId';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => AudioPrediction.fromJson(json)).toList();
    } else {
      _handleError(response);
      return [];
    }
  }

  Future<AudioPrediction> getPrediction(String predictionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/audio/predictions/$predictionId'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return AudioPrediction.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to load prediction');
    }
  }

  // ==================== MAINTENANCE ENDPOINTS ====================

  Future<List<Maintenance>> getMaintenance(
    String tractorId, {
    bool completed = false,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/maintenance/$tractorId?completed=$completed'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Maintenance.fromJson(json)).toList();
    } else {
      _handleError(response);
      return [];
    }
  }

  Future<Maintenance> createMaintenance(
    String tractorId,
    Map<String, dynamic> maintenanceData,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/maintenance/$tractorId'),
      headers: _getHeaders(),
      body: json.encode(maintenanceData),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Maintenance.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to create maintenance');
    }
  }

  Future<Maintenance> updateMaintenance(
    String tractorId,
    String maintenanceId,
    Map<String, dynamic> maintenanceData,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/maintenance/$tractorId/$maintenanceId'),
      headers: _getHeaders(),
      body: json.encode(maintenanceData),
    );

    if (response.statusCode == 200) {
      return Maintenance.fromJson(json.decode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to update maintenance');
    }
  }

  Future<void> deleteMaintenance(
    String tractorId,
    String maintenanceId,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/maintenance/$tractorId/$maintenanceId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      _handleError(response);
    }
  }
}

// Custom exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}