import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/tractor.dart';
import '../models/audio_prediction.dart';
import '../models/maintenance.dart';
import 'storage_service.dart';

class ApiService {
  // Singleton pattern to ensure same instance across app
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String baseUrl = AppConfig.apiBaseUrl;
  String? _token;

  void setToken(String token) {
    _token = token;
    AppConfig.log('🔑 Token set: ${token.substring(0, 20)}...');
  }
  
  void clearToken() {
    _token = null;
    AppConfig.log('🔑 Token cleared');
  }
  
  String? get currentToken => _token;

  // Ensure token is loaded from storage if not already set
  Future<void> ensureTokenLoaded() async {
    if (_token == null) {
      AppConfig.log('🔄 Token not set, attempting to load from storage...');
      // Import storage service to get token
      final StorageService storage = StorageService();
      final savedToken = await storage.getToken();
      if (savedToken != null) {
        setToken(savedToken);
        AppConfig.log('✅ Token loaded from storage');
      } else {
        AppConfig.log('❌ No token found in storage');
      }
    }
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    return AppConfig.getHeaders(token: includeAuth ? _token : null);
  }

  Map<String, String> _getMultipartHeaders() {
    return AppConfig.getMultipartHeaders(token: _token);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final loginUrl = AppConfig.getApiUrl('${AppConfig.authEndpoint}/login');
    AppConfig.log('🔑 Attempting login to: $loginUrl');
    AppConfig.log('📧 Email: $email');
    
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({'email': email, 'password': password}),
      ).timeout(
        Duration(seconds: AppConfig.apiTimeout),
        onTimeout: () {
          throw Exception('Connection timeout - Please check your internet connection');
        },
      );
      
      AppConfig.log('📡 Response status: ${response.statusCode}');
      AppConfig.log('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppConfig.logSuccess('✅ Login successful!');
        return data;
      } else {
        throw Exception('Login failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Login error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.getApiUrl('${AppConfig.authEndpoint}/me')),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get user info - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('Get user error', e);
      rethrow;
    }
  }

  Future<List<Tractor>> getTractors() async {
    // Ensure token is loaded before making request
    await ensureTokenLoaded();
    
    final tractorsUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/');
    AppConfig.log('🚜 Fetching tractors from: $tractorsUrl');
    AppConfig.log('🔐 Token available: ${_token != null}');
    if (_token != null) {
      AppConfig.log('🔑 Token preview: ${_token!.substring(0, 20)}...');
    }
    
    try {
      final headers = _getHeaders();
      AppConfig.log('📋 Request headers: $headers');
      
      final response = await http.get(
        Uri.parse(tractorsUrl),
        headers: headers,
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      AppConfig.log('📡 Tractors response status: ${response.statusCode}');
      AppConfig.log('📄 Tractors response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppConfig.log('📊 Parsed data structure: ${data.runtimeType}');
        
        List<dynamic> tractorsList;
        if (data is List) {
          tractorsList = data;
        } else if (data is Map && data.containsKey('tractors')) {
          tractorsList = data['tractors'];
        } else if (data is Map && data.containsKey('data')) {
          tractorsList = data['data'];
        } else {
          AppConfig.logError('❌ Unexpected response format', data);
          tractorsList = [];
        }
        
        AppConfig.logSuccess('✅ Found ${tractorsList.length} tractors from API');
        AppConfig.log('🔍 First tractor preview: ${tractorsList.isNotEmpty ? tractorsList[0] : 'None'}');
        
        return tractorsList.map((json) => Tractor.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - Please login again');
      } else if (response.statusCode == 403) {
        throw Exception('Not authorized to access tractors');
      } else {
        throw Exception('Failed to get tractors - Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Get tractors error', e);
      rethrow;
    }
  }

  Future<Tractor> createTractor(Map<String, dynamic> tractorData) async {
    // Ensure token is loaded before making request
    await ensureTokenLoaded();
    
    AppConfig.log('🆕 Creating tractor: ${tractorData['tractor_id']}');
    AppConfig.log('🔐 Token available: ${_token != null}');
    if (_token != null) {
      AppConfig.log('🔑 Token preview: ${_token!.substring(0, 20)}...');
    }
    AppConfig.log('📊 Data: $tractorData');
    
    try {
      final headers = _getHeaders();
      AppConfig.log('📋 Request headers: $headers');
      
      final response = await http.post(
        Uri.parse(AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/')),
        headers: headers,
        body: json.encode(tractorData),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      AppConfig.log('📡 Create response status: ${response.statusCode}');
      AppConfig.log('📄 Create response: ${response.body}');
      
      if (response.statusCode == 201) {
        AppConfig.logSuccess('✅ Tractor created successfully!');
        return Tractor.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - Please login again');
      } else if (response.statusCode == 403) {
        throw Exception('Not authorized to create tractors');
      }
      throw Exception('Failed to create tractor - Status: ${response.statusCode}: ${response.body}');
    } catch (e) {
      AppConfig.logError('❌ Create tractor error', e);
      rethrow;
    }
  }

  Future<AudioPrediction> predictAudio({
    required File audioFile,
    required String tractorId,
    required double engineHours,
  }) async {
    try {
      AppConfig.log('🎵 Starting audio prediction for tractor: $tractorId');
      
      // Create multipart request for audio upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.getApiUrl('${AppConfig.audioEndpoint}/upload')).replace(queryParameters: {
          'tractor_id': tractorId,
          'tractor_hours': engineHours.toString(),
        }),
      );

      // Add authorization header using AppConfig
      request.headers.addAll(_getMultipartHeaders());

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
    final maintenanceUrl = AppConfig.getApiUrl('${AppConfig.maintenanceEndpoint}/');
    AppConfig.log('🔧 Fetching maintenance tasks for tractor: $tractorId');
    
    try {
      final response = await http.get(
        Uri.parse(maintenanceUrl).replace(queryParameters: {
          'tractor_id': tractorId,
          'completed': completed.toString(),
        }),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> maintenanceList = data['maintenance_tasks'] ?? data;
        return maintenanceList.map((json) => Maintenance.fromJson(json)).toList();
      }
      throw Exception('Failed to get maintenance tasks - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get maintenance tasks error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  // Additional methods that were missing
  Future<Tractor> getTractor(String tractorId) async {
    final tractorUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/$tractorId');
    AppConfig.log('🚜 Fetching tractor: $tractorId');
    
    try {
      final response = await http.get(
        Uri.parse(tractorUrl),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        return Tractor.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get tractor - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get tractor error', e);
      rethrow;
    }
  }

  Future<Tractor> updateTractor(String tractorId, Map<String, dynamic> updates) async {
    final updateUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/$tractorId');
    AppConfig.log('🚜 Updating tractor: $tractorId');
    
    try {
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: _getHeaders(),
        body: json.encode(updates),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        AppConfig.logSuccess('✅ Tractor updated successfully');
        return Tractor.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to update tractor - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Update tractor error', e);
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
    final predictionsUrl = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/predictions');
    AppConfig.log('🎵 Fetching predictions for tractor: $tractorId');
    
    try {
      final response = await http.get(
        Uri.parse(predictionsUrl).replace(queryParameters: {
          'tractor_id': tractorId,
        }),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> predictionsList = data['predictions'] ?? data;
        return predictionsList.map((json) => AudioPrediction.fromJson(json)).toList();
      }
      throw Exception('Failed to get predictions - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get predictions error', e);
      rethrow; // No mock fallback - only live data
    }
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

  Future<AudioPrediction> uploadAudioBytes({
    required List<int> bytes,
    required String filename,
    required String tractorId,
    required double engineHours,
  }) async {
    try {
      AppConfig.log('🎵 Starting audio prediction with bytes for tractor: $tractorId');
      
      // Create multipart request for audio upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.getApiUrl('${AppConfig.audioEndpoint}/upload')).replace(queryParameters: {
          'tractor_id': tractorId,
          'tractor_hours': engineHours.toString(),
        }),
      );

      // Add authorization header using AppConfig
      request.headers.addAll(_getMultipartHeaders());

      // Add the audio file from bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
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

  Future<AudioPrediction> getPrediction(String predictionId) async {
    final predictionUrl = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/predictions/$predictionId');
    AppConfig.log('🎵 Fetching prediction: $predictionId');
    
    try {
      final response = await http.get(
        Uri.parse(predictionUrl),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AudioPrediction.fromJson(data);
      }
      throw Exception('Failed to get prediction - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get prediction error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  Future<List<Maintenance>> getMaintenance(String tractorId, {bool completed = false}) async {
    return getMaintenanceTasks(tractorId, completed: completed);
  }

  Future<Maintenance> updateMaintenance(String maintenanceId, Map<String, dynamic> updates) async {
    final updateUrl = AppConfig.getApiUrl('${AppConfig.maintenanceEndpoint}/$maintenanceId');
    AppConfig.log('🔧 Updating maintenance: $maintenanceId');
    
    try {
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: _getHeaders(),
        body: json.encode(updates),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Maintenance.fromJson(data);
      }
      throw Exception('Failed to update maintenance - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Update maintenance error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  Future<void> deleteMaintenance(String maintenanceId) async {
    final deleteUrl = AppConfig.getApiUrl('${AppConfig.maintenanceEndpoint}/$maintenanceId');
    AppConfig.log('🗑️ Deleting maintenance: $maintenanceId');
    
    try {
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete maintenance - Status: ${response.statusCode}');
      }
      AppConfig.logSuccess('✅ Maintenance deleted successfully');
    } catch (e) {
      AppConfig.logError('❌ Delete maintenance error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  Future<Maintenance> createMaintenance(Map<String, dynamic> maintenanceData) async {
    final createUrl = AppConfig.getApiUrl('${AppConfig.maintenanceEndpoint}/');
    AppConfig.log('🔧 Creating maintenance task');
    
    try {
      final response = await http.post(
        Uri.parse(createUrl),
        headers: _getHeaders(),
        body: json.encode(maintenanceData),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        AppConfig.logSuccess('✅ Maintenance created successfully');
        return Maintenance.fromJson(data);
      }
      throw Exception('Failed to create maintenance - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Create maintenance error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    final registerUrl = AppConfig.getApiUrl('${AppConfig.authEndpoint}/register');
    AppConfig.log('📝 Attempting registration to: $registerUrl');
    AppConfig.log('📧 Email: $email');
    
    try {
      final response = await http.post(
        Uri.parse(registerUrl),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      ).timeout(
        Duration(seconds: AppConfig.apiTimeout),
        onTimeout: () {
          throw Exception('Registration timeout - Please check your internet connection');
        },
      );
      
      AppConfig.log('📡 Registration response status: ${response.statusCode}');
      AppConfig.log('📄 Registration response: ${response.body}');
      
      if (response.statusCode == 201) {
        AppConfig.logSuccess('✅ Registration successful!');
        return json.decode(response.body);
      }
      throw Exception('Registration failed with status ${response.statusCode}: ${response.body}');
    } catch (e) {
      AppConfig.logError('❌ Registration error', e);
      rethrow; // No mock fallback - only live data
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
