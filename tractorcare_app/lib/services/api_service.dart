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

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth && _token != null) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    print('🔑 Attempting login to: $baseUrl/auth/login');
    print('📧 Email: $email');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({'email': email, 'password': password}),
      );
      
      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Login successful!');
        return data;
      } else {
        throw Exception('Login failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get user info');
    } catch (e) {
      print('Get user error: $e');
      rethrow;
    }
  }

  Future<List<Tractor>> getTractors() async {
    print('🚜 Fetching tractors from: $baseUrl/tractors/');
    print('🔐 Token available: ${_token != null}');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tractors/'),
        headers: _getHeaders(),
      );
      
      print('📡 Tractors response status: ${response.statusCode}');
      print('📄 Tractors response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tractorsList = data['tractors'] ?? data;
        print('✅ Found ${tractorsList.length} tractors from API');
        return tractorsList.map((json) => Tractor.fromJson(json)).toList();
      }
      throw Exception('Failed to get tractors - Status: ${response.statusCode}');
    } catch (e) {
      print('❌ Get tractors error: $e');
      rethrow;
    }
  }

  Future<Tractor> createTractor(Map<String, dynamic> tractorData) async {
    print('🆕 Creating tractor: ${tractorData['tractor_id']}');
    print('🔐 Token available: ${_token != null}');
    print('📊 Data: $tractorData');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tractors/'),
        headers: _getHeaders(),
        body: json.encode(tractorData),
      );
      
      print('📡 Create response status: ${response.statusCode}');
      print('📄 Create response: ${response.body}');
      
      if (response.statusCode == 201) {
        print('✅ Tractor created successfully!');
        return Tractor.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to create tractor - Status: ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('❌ Create tractor error: $e');
      rethrow;
    }
  }

  Future<AudioPrediction> predictAudio({
    required File audioFile,
    required String tractorId,
    required double engineHours,
  }) async {
    try {
      // Create multipart request for audio upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/audio/upload').replace(queryParameters: {
          'tractor_id': tractorId,
          'tractor_hours': engineHours.toString(),
        }),
      );

      // Add authorization header
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      // Add the audio file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
      ));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AudioPrediction.fromJson({
          'id': data['id'],
          'tractor_id': data['tractor_id'],
          'prediction_class': data['prediction_class'],
          'confidence': data['confidence'],
          'anomaly_score': data['anomaly_score'] ?? 0.0,
          'audio_file_path': data['file_path'],
          'recorded_at': data['recorded_at'],
        });
      } else {
        throw Exception('Audio upload failed: ${response.body}');
      }
    } catch (e) {
      print('Audio upload error: $e');
      rethrow;
    }
  }

  Future<List<Maintenance>> getMaintenanceTasks(String tractorId, {bool completed = false}) async {
    return [
      Maintenance.fromJson({
        'id': 'maintenance_001',
        'tractor_id': tractorId,
        'title': 'Oil Change',
        'description': 'Replace engine oil and filter',
        'priority': 'medium',
        'estimated_cost': 50000.0,
        'completed': false,
        'due_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      }),
    ];
  }

  // Additional methods that were missing
  Future<Tractor> getTractor(String tractorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tractors/$tractorId'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return Tractor.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get tractor');
    } catch (e) {
      rethrow;
    }
  }

  Future<Tractor> updateTractor(String tractorId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tractors/$tractorId'),
        headers: _getHeaders(),
        body: json.encode(updates),
      );
      if (response.statusCode == 200) {
        return Tractor.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to update tractor');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTractor(String tractorId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tractors/$tractorId'),
        headers: _getHeaders(),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete tractor');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AudioPrediction>> getPredictions(String tractorId) async {
    return [
      AudioPrediction.fromJson({
        'id': 'prediction_001',
        'tractor_id': tractorId,
        'prediction_class': 'Normal',
        'confidence': 0.89,
        'anomaly_score': 0.11,
        'audio_file_path': 'mock/audio/path1.wav',
        'recorded_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      }),
      AudioPrediction.fromJson({
        'id': 'prediction_002',
        'tractor_id': tractorId,
        'prediction_class': 'Anomaly',
        'confidence': 0.76,
        'anomaly_score': 0.24,
        'audio_file_path': 'mock/audio/path2.wav',
        'recorded_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      }),
    ];
  }

  Future<AudioPrediction> uploadAudio({
    required File audioFile,
    required String tractorId,
    required double engineHours,
  }) async {
    return predictAudio(
      audioFile: audioFile,
      tractorId: tractorId,
      engineHours: engineHours,
    );
  }

  Future<AudioPrediction> getPrediction(String predictionId) async {
    return AudioPrediction.fromJson({
      'id': predictionId,
      'tractor_id': 'tractor_001',
      'prediction_class': 'Normal',
      'confidence': 0.89,
      'anomaly_score': 0.11,
      'audio_file_path': 'mock/audio/path.wav',
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Maintenance>> getMaintenance(String tractorId, {bool completed = false}) async {
    return getMaintenanceTasks(tractorId, completed: completed);
  }

  Future<Maintenance> updateMaintenance(String maintenanceId, Map<String, dynamic> updates) async {
    return Maintenance.fromJson({
      'id': maintenanceId,
      'tractor_id': updates['tractor_id'] ?? 'tractor_001',
      'title': updates['title'] ?? 'Updated Task',
      'description': updates['description'] ?? 'Updated description',
      'priority': updates['priority'] ?? 'medium',
      'estimated_cost': updates['estimated_cost'] ?? 50000.0,
      'completed': updates['completed'] ?? false,
      'due_date': updates['due_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMaintenance(String maintenanceId) async {
    // Mock implementation - just return success
    return;
  }

  Future<Maintenance> createMaintenance(Map<String, dynamic> maintenanceData) async {
    return Maintenance.fromJson({
      'id': 'maintenance_${DateTime.now().millisecondsSinceEpoch}',
      'tractor_id': maintenanceData['tractor_id'],
      'title': maintenanceData['title'],
      'description': maintenanceData['description'],
      'priority': maintenanceData['priority'] ?? 'medium',
      'estimated_cost': maintenanceData['estimated_cost'] ?? 0.0,
      'completed': false,
      'due_date': maintenanceData['due_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );
      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Registration failed');
    } catch (e) {
      // Mock fallback
      return {
        'access_token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        'token_type': 'bearer',
        'user': {
          'id': 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
          'email': email,
          'full_name': fullName,
        }
      };
    }
  }

  // ===== BASELINE COLLECTION METHODS =====
  
  Future<Map<String, dynamic>> startBaselineCollection({
    required String tractorId,
    int targetSamples = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/baseline/$tractorId/start').replace(queryParameters: {
          'target_samples': targetSamples.toString(),
        }),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to start baseline collection: ${response.body}');
      }
    } catch (e) {
      print('Baseline start error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addBaselineSample({
    required String tractorId,
    required File audioFile,
  }) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/baseline/$tractorId/add-sample'),
      );

      // Add authorization header
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      // Add the audio file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        audioFile.path,
      ));

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add baseline sample: ${response.body}');
      }
    } catch (e) {
      print('Baseline sample error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> finalizeBaseline(String tractorId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/baseline/$tractorId/finalize'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to finalize baseline: ${response.body}');
      }
    } catch (e) {
      print('Baseline finalize error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBaselineStatus(String tractorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/baseline/$tractorId/status'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get baseline status: ${response.body}');
      }
    } catch (e) {
      print('Baseline status error: $e');
      rethrow;
    }
  }

  // ===== USAGE TRACKING METHODS =====

  Future<Map<String, dynamic>> logDailyUsage(
    String tractorId,
    double endHours,
    String? notes,
  ) async {
    print('📊 Logging usage for tractor: $tractorId');
    print('⏰ End hours: $endHours');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/usage-tracking/$tractorId/log'),
        headers: _getHeaders(),
        body: json.encode({
          'end_hours': endHours,
          'notes': notes,
        }),
      );
      
      print('📡 Usage log response: ${response.statusCode}');
      print('📄 Usage log body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to log usage: ${response.body}');
    } catch (e) {
      print('❌ Usage log error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUsageStats(String tractorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usage-tracking/$tractorId/stats'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get usage stats');
    } catch (e) {
      print('Usage stats error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getUsageHistory(String tractorId, {int days = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/usage-tracking/$tractorId/history').replace(queryParameters: {
          'days': days.toString(),
        }),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['history'] ?? data;
      }
      throw Exception('Failed to get usage history');
    } catch (e) {
      print('Usage history error: $e');
      rethrow;
    }
  }

  Future<Tractor> getTractorById(String tractorId) async {
    return getTractor(tractorId);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}
