import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Only import dart:io on non-web platforms  
import 'dart:io' if (dart.library.html) 'dart:html';
import '../config/app_config.dart';
import '../models/tractor.dart';
import '../models/tractor_summary.dart';
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
      // Test connectivity first
      AppConfig.log('🌐 Testing network connectivity...');
      
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({'email': email, 'password': password}),
      ).timeout(
        Duration(seconds: AppConfig.apiTimeout),
        onTimeout: () {
          AppConfig.logError('⏰ Request timed out after ${AppConfig.apiTimeout} seconds');
          throw Exception('Connection timeout - Server took too long to respond. Please try again.');
        },
      );
      
      AppConfig.log('📡 Response status: ${response.statusCode}');
      AppConfig.log('📄 Response headers: ${response.headers}');
      AppConfig.log('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppConfig.logSuccess('✅ Login successful!');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid email or password. Please check your credentials.');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error (${response.statusCode}). Please try again later.');
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } on http.ClientException catch (e) {
      AppConfig.logError('❌ Network error: $e');
      throw Exception('Network connection failed. Please check your internet connection and try again.');
    } on FormatException catch (e) {
      AppConfig.logError('❌ Response parsing error: $e');
      throw Exception('Invalid response from server. Please try again.');
    } catch (e) {
      AppConfig.logError('❌ Login error: $e');
      if (e.toString().contains('Failed to fetch') || e.toString().contains('XMLHttpRequest error')) {
        throw Exception('Network request failed. This might be a CORS issue. Please contact support.');
      }
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
    
    // Ensure the data matches backend expectations
    final formattedData = {
      'tractor_id': tractorData['tractor_id'],
      'model': tractorData['model'],
      'purchase_date': tractorData['purchase_date'] ?? DateTime.now().toIso8601String(),
      'engine_hours': tractorData['engine_hours'] ?? 0,
      'usage_intensity': tractorData['usage_intensity'] ?? 'moderate',
    };
    
    AppConfig.log('📊 Formatted data: $formattedData');
    
    try {
      final headers = _getHeaders();
      AppConfig.log('📋 Request headers: $headers');
      
      final response = await http.post(
        Uri.parse(AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/')),
        headers: headers,
        body: json.encode(formattedData),
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
    dynamic audioFile,  // File on mobile, not used on web
    Uint8List? audioBytes,
    String? fileName,
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

      // Add the audio file - handle both mobile and web
      if (audioFile != null && !kIsWeb) {
        // Mobile/Desktop - use file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
        ));
      } else if (audioBytes != null && fileName != null) {
        // Web - use bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: fileName,
        ));
      } else {
        throw Exception('Either audioFile or audioBytes must be provided');
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Normalize backend response to AudioPrediction.fromJson expectations
        final Map<String, dynamic> normalized = {
          'id': data['id'],
          'tractor_id': data['tractor_id'],
          'prediction_class': data['prediction_class'],
          'confidence': data['confidence'],
          'anomaly_score': data['anomaly_score'] ?? 0.0,
          'audio_path': data['file_path'] ?? data['audio_file_path'] ?? '',
          'created_at': data['recorded_at'] ?? data['created_at'],
          'duration_seconds': data['duration_seconds'] ?? data['duration'] ?? null,
          'baseline_comparison': data['baseline_comparison'] ?? null,
        };
        return AudioPrediction.fromJson(normalized);
      } else {
        throw Exception('Audio upload failed: ${response.body}');
      }
    } catch (e) {
      print('Audio upload error: $e');
      rethrow;
    }
  }

  Future<List<Maintenance>> getMaintenanceTasks(String tractorId, {bool completed = false}) async {
    AppConfig.log('🔧 Fetching maintenance (${completed ? 'completed' : 'upcoming'}) for tractor: $tractorId');
    
    // TODO: Replace with actual API calls when backend endpoints are implemented
    // For now, return mock data to allow UI testing
    
    if (completed) {
      // Return mock completed maintenance tasks
      return [
        Maintenance(
          id: 'maint_001',
          tractorId: tractorId,
          userId: 'user_001',
          type: MaintenanceType.service,
          customType: 'Oil Change',
          dueDate: DateTime.now().subtract(const Duration(days: 30)),
          notes: 'Regular oil change completed',
          status: MaintenanceStatus.completed,
          completedAt: DateTime.now().subtract(const Duration(days: 30)),
          actualCost: 45000.0,
          createdAt: DateTime.now().subtract(const Duration(days: 35)),
        ),
        Maintenance(
          id: 'maint_002',
          tractorId: tractorId,
          userId: 'user_001',
          type: MaintenanceType.inspection,
          customType: 'Filter Replacement',
          dueDate: DateTime.now().subtract(const Duration(days: 60)),
          notes: 'Air and fuel filters replaced',
          status: MaintenanceStatus.completed,
          completedAt: DateTime.now().subtract(const Duration(days: 60)),
          actualCost: 25000.0,
          createdAt: DateTime.now().subtract(const Duration(days: 65)),
        ),
      ];
    } else {
      // Return mock upcoming maintenance tasks
      return [
        Maintenance(
          id: 'maint_003',
          tractorId: tractorId,
          userId: 'user_001',
          type: MaintenanceType.service,
          customType: 'Oil Change',
          dueDate: DateTime.now().add(const Duration(days: 7)),
          notes: 'Regular oil change due soon',
          status: MaintenanceStatus.due,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Maintenance(
          id: 'maint_004',
          tractorId: tractorId,
          userId: 'user_001',
          type: MaintenanceType.inspection,
          customType: 'Annual Inspection',
          dueDate: DateTime.now().add(const Duration(days: 30)),
          notes: 'Annual safety and performance inspection',
          status: MaintenanceStatus.upcoming,
          createdAt: DateTime.now(),
        ),
        Maintenance(
          id: 'maint_005',
          tractorId: tractorId,
          userId: 'user_001',
          type: MaintenanceType.repair,
          customType: 'Hydraulic System Check',
          dueDate: DateTime.now().subtract(const Duration(days: 2)),
          notes: 'Overdue hydraulic system maintenance',
          status: MaintenanceStatus.overdue,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ];
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
    final predictionsUrl = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/$tractorId/predictions');
    AppConfig.log('🎵 Fetching predictions for tractor: $tractorId');
    
    try {
      final response = await http.get(
        Uri.parse(predictionsUrl),
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
    dynamic audioFile,  // File on mobile, not used on web
    Uint8List? audioBytes,
    String? fileName,
    required String tractorId,
    required double engineHours,
  }) async {
    return predictAudio(
      audioFile: audioFile,
      audioBytes: audioBytes,
      fileName: fileName,
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
        final Map<String, dynamic> normalized = {
          'id': data['id'],
          'tractor_id': data['tractor_id'],
          'prediction_class': data['prediction_class'],
          'confidence': data['confidence'],
          'anomaly_score': data['anomaly_score'] ?? 0.0,
          'audio_path': data['file_path'] ?? data['audio_file_path'] ?? '',
          'created_at': data['recorded_at'] ?? data['created_at'],
          'duration_seconds': data['duration_seconds'] ?? data['duration'] ?? null,
          'baseline_comparison': data['baseline_comparison'] ?? null,
        };
        return AudioPrediction.fromJson(normalized);
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
        // Normalize keys similar to upload response
        final Map<String, dynamic> normalized = Map<String, dynamic>.from(data);
        if (data['recorded_at'] != null && data['created_at'] == null) normalized['created_at'] = data['recorded_at'];
        if (data['baseline_comparison'] != null && data['baseline_comparison']['deviation_score'] != null) {
          normalized['baseline_comparison'] = data['baseline_comparison'];
        }
        return AudioPrediction.fromJson(normalized);
      }
      throw Exception('Failed to get prediction - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get prediction error', e);
      rethrow; // No mock fallback - only live data
    }
  }

  Future<void> deletePrediction({
    required String tractorId,
    required String predictionId,
  }) async {
    AppConfig.log('🗑️ Deleting prediction $predictionId for tractor $tractorId');
    try {
      final url = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/$tractorId/predictions/$predictionId');
      final response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));

      if (response.statusCode == 200 || response.statusCode == 204) {
        AppConfig.logSuccess('✅ Prediction deleted');
        return;
      }
      throw Exception('Failed to delete prediction - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Delete prediction error', e);
      rethrow;
    }
  }

  Future<List<Maintenance>> getMaintenance(String tractorId, {bool completed = false}) async {
    return getMaintenanceTasks(tractorId, completed: completed);
  }

  Future<Maintenance> updateMaintenance(String maintenanceId, Map<String, dynamic> updates) async {
    AppConfig.log('🔧 Updating maintenance: $maintenanceId (mock data)');
    
    // TODO: Replace with actual API call when backend endpoint is implemented
    // For now, return mock updated maintenance data
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay
    
    final now = DateTime.now();
    return Maintenance(
      id: maintenanceId,
      tractorId: updates['tractor_id'] ?? 'unknown',
      userId: updates['user_id'] ?? 'user_001',
      type: updates['type'] != null 
        ? MaintenanceType.values.firstWhere(
            (type) => type.toString().split('.').last == updates['type'],
            orElse: () => MaintenanceType.service,
          )
        : MaintenanceType.service,
      customType: updates['custom_type'] ?? 'Updated Service',
      dueDate: updates['due_date'] != null 
        ? DateTime.parse(updates['due_date'])
        : now.add(const Duration(days: 30)),
      notes: updates['notes'],
      status: updates['status'] != null
        ? MaintenanceStatus.values.firstWhere(
            (status) => status.toString().split('.').last == updates['status'],
            orElse: () => MaintenanceStatus.upcoming,
          )
        : MaintenanceStatus.upcoming,
      completedAt: updates['completed_at'] != null ? DateTime.parse(updates['completed_at']) : null,
      actualCost: updates['actual_cost']?.toDouble(),
      createdAt: now.subtract(const Duration(days: 1)),
    );
  }

  Future<void> deleteMaintenance(String maintenanceId) async {
    AppConfig.log('🗑️ Deleting maintenance: $maintenanceId (mock operation)');
    
    // TODO: Replace with actual API call when backend endpoint is implemented
    // For now, simulate successful deletion
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    AppConfig.logSuccess('✅ Maintenance deleted successfully (mock)');
  }

  Future<Maintenance> createMaintenance(Map<String, dynamic> maintenanceData) async {
    AppConfig.log('🔧 Creating maintenance task (mock data)');
    
    // TODO: Replace with actual API call when backend endpoint is implemented
    // For now, return mock created maintenance data
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    
    final now = DateTime.now();
    return Maintenance(
      id: 'maint_${now.millisecondsSinceEpoch}',
      tractorId: maintenanceData['tractor_id'] ?? '',
      userId: maintenanceData['user_id'] ?? 'user_001',
      type: MaintenanceType.values.firstWhere(
        (type) => type.toString().split('.').last == maintenanceData['type'],
        orElse: () => MaintenanceType.service,
      ),
      customType: maintenanceData['custom_type'] ?? 'Service',
      dueDate: DateTime.parse(maintenanceData['due_date'] ?? now.add(const Duration(days: 30)).toIso8601String()),
      notes: maintenanceData['notes'],
      status: MaintenanceStatus.upcoming,
      createdAt: now,
    );
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
    AppConfig.log('🎯 Starting baseline collection for tractor: $tractorId');
    try {
      final url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/start');
      final response = await http.post(
        Uri.parse(url).replace(queryParameters: {
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
    dynamic audioFile,  // File on mobile, not used on web
    Uint8List? audioBytes,
    String? fileName,
  }) async {
    AppConfig.log('🎵 Adding baseline sample for tractor: $tractorId');
    try {
      // Create multipart request
      final url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/add-sample');
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(url),
      );

      // Add authorization header using AppConfig
      request.headers.addAll(_getMultipartHeaders());

      // Add the audio file - handle both mobile and web
      if (audioFile != null && !kIsWeb) {
        // Mobile/Desktop - use file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
        ));
      } else if (audioBytes != null && fileName != null) {
        // Web - use bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: fileName,
        ));
      } else {
        throw Exception('Either audioFile or audioBytes must be provided');
      }

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

  Future<Map<String, dynamic>> finalizeBaseline({
    required String tractorId,
    double? tractorHours,
    String? loadCondition,
    String? notes,
  }) async {
    AppConfig.log('✅ Finalizing baseline for tractor: $tractorId');
    try {
      final queryParams = <String, String>{};
      if (tractorHours != null) queryParams['tractor_hours'] = tractorHours.toString();
      if (loadCondition != null) queryParams['load_condition'] = loadCondition;
      if (notes != null) queryParams['notes'] = notes;
      
      final url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/finalize');
      
      final response = await http.post(
        Uri.parse(url).replace(queryParameters: queryParams),
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

  Future<Map<String, dynamic>> getBaselineHistory(String tractorId) async {
    AppConfig.log('📊 Getting baseline history for tractor: $tractorId');
    try {
      final url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/history');
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        // No baseline history found
        return {
          'tractor_id': tractorId,
          'total_baselines': 0,
          'history': []
        };
      } else {
        throw Exception('Failed to get baseline history: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Baseline history error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteBaseline({
    required String tractorId,
    required String baselineId,
  }) async {
    AppConfig.log('🗑️ Deleting baseline $baselineId for tractor: $tractorId');
    try {
      // Try deleting specific baseline first (if backend supports it)
      var url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/$baselineId');
      var response = await http.delete(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      // If specific baseline delete is not supported (404), fall back to tractor-level delete
      if (response.statusCode == 404) {
        AppConfig.log('🔄 Specific baseline delete not supported, using tractor-level delete');
        url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId');
        response = await http.delete(
          Uri.parse(url),
          headers: _getHeaders(),
        );
      }

      if (response.statusCode == 200) {
        AppConfig.logSuccess('✅ Baseline deleted successfully');
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Baseline not found');
      } else if (response.statusCode == 403) {
        throw Exception('Cannot delete active baseline that is being used for analysis');
      } else {
        throw Exception('Failed to delete baseline: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Delete baseline error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getBaselineStatus(String tractorId) async {
    AppConfig.log('📊 Getting baseline status for tractor: $tractorId');
    try {
      final url = AppConfig.getApiUrl('${AppConfig.baselineEndpoint}/$tractorId/status');
      final response = await http.get(
        Uri.parse(url),
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
        Uri.parse('$baseUrl${AppConfig.usageEndpoint}/$tractorId/log'),
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
        Uri.parse('$baseUrl${AppConfig.usageEndpoint}/$tractorId/stats'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      // If endpoint is not available yet or tractor has no stats, return empty map instead of throwing
      if (response.statusCode == 404 || response.statusCode == 204) {
        return {};
      }
      throw Exception('Failed to get usage stats');
    } catch (e) {
      print('Usage stats error: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getUsageHistory(String tractorId, {int days = 30}) async {
    await ensureTokenLoaded();
    
    try {
      AppConfig.log('📊 Fetching usage history for tractor: $tractorId (last $days days)');
      
      final url = '${AppConfig.getApiUrl(AppConfig.usageEndpoint)}/$tractorId/history';
      final uri = Uri.parse(url).replace(queryParameters: {
        'days': days.toString(),
      });
      
      AppConfig.log('📡 Usage history URL: $uri');
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      AppConfig.log('📡 Usage history response status: ${response.statusCode}');
      AppConfig.log('📄 Usage history response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats
        List<dynamic> historyList;
        if (data is List) {
          historyList = data;
        } else if (data is Map && data['history'] != null) {
          historyList = data['history'] is List ? data['history'] : [];
        } else if (data is Map && data['data'] != null) {
          historyList = data['data'] is List ? data['data'] : [];
        } else {
          historyList = [];
        }
        
        AppConfig.log('✅ Usage history parsed: ${historyList.length} records');
        return historyList;
      } else if (response.statusCode == 404) {
        AppConfig.log('ℹ️ No usage history found for tractor $tractorId');
        return [];
      }
      throw Exception('Failed to get usage history - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Usage history error', e);
      rethrow;
    }
  }

  Future<Tractor> getTractorById(String tractorId) async {
    return getTractor(tractorId);
  }

  // ===== MAINTENANCE METHODS =====
  
  Future<List<dynamic>> getMaintenanceAlerts(String tractorId) async {
    AppConfig.log('🔧 Fetching maintenance alerts for tractor: $tractorId');
    
    // TODO: Replace with actual API call when backend endpoint is implemented
    // For now, return mock maintenance alerts data
    return [
      {
        'id': 'alert_001',
        'tractor_id': tractorId,
        'task_name': 'Oil Change',
        'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'description': 'Regular oil change due soon',
        'status': 'due',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': 'alert_002',
        'tractor_id': tractorId,
        'task_name': 'Hydraulic System Check',
        'due_date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'description': 'Overdue hydraulic system maintenance',
        'status': 'overdue',
        'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      },
    ];
  }

  Future<TractorSummary> getTractorSummary(String tractorId) async {
    await ensureTokenLoaded();
    
    final summaryUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/$tractorId/summary');
    AppConfig.log('📊 Fetching tractor summary: $tractorId from $summaryUrl');
    
    try {
      final response = await http.get(
        Uri.parse(summaryUrl),
        headers: _getHeaders(),
      ).timeout(Duration(seconds: AppConfig.apiTimeout));
      
      AppConfig.log('📡 Summary response status: ${response.statusCode}');
      AppConfig.log('📄 Summary response body: ${response.body}');
      
      if (response.statusCode == 200) {
        AppConfig.logSuccess('✅ Tractor summary retrieved successfully');
        return TractorSummary.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Tractor not found: $tractorId');
      }
      throw Exception('Failed to get tractor summary - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get tractor summary error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl${AppConfig.statisticsEndpoint}/user'),
        headers: _getHeaders(),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to get user statistics');
    } catch (e) {
      AppConfig.logError('Get user statistics error', e);
      rethrow;
    }
  }

  // Test method to verify T007 tractor connectivity
  Future<void> testTractorT007() async {
    AppConfig.log('🧪 Testing T007 tractor endpoints...');
    
    try {
      // Test get specific tractor
      final tractor = await getTractor('T007');
      AppConfig.logSuccess('✅ GET /tractors/T007 - Success: ${tractor.model}');
      
      // Test get tractor summary
      final summary = await getTractorSummary('T007');
      AppConfig.logSuccess('✅ GET /tractors/T007/summary - Success: Health score ${summary.healthScore}');
      
      // Test baseline status
      final baselineStatus = await getBaselineStatus('T007');
      AppConfig.logSuccess('✅ GET /baseline/T007/status - Success: ${baselineStatus['baseline_status']}');
      
      AppConfig.logSuccess('🎉 All T007 endpoints working correctly!');
    } catch (e) {
      AppConfig.logError('❌ T007 test failed', e);
      rethrow;
    }
  }

  // Test baseline API compatibility
  Future<Map<String, dynamic>> testBaselineUpload(String tractorId) async {
    AppConfig.log('🧪 Testing baseline API format for tractor: $tractorId');
    
    try {
      // First check if baseline exists and get status
      final status = await getBaselineStatus(tractorId);
      AppConfig.log('📊 Current baseline status: ${status['baseline_status']}');
      
      return {
        'status': 'ready_for_upload',
        'tractor_id': tractorId,
        'baseline_status': status['baseline_status'],
        'message': 'Baseline API ready for file upload'
      };
    } catch (e) {
      AppConfig.logError('❌ Baseline test failed', e);
      rethrow;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}
