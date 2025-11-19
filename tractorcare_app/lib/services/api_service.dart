import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  final String baseUrl = AppConfig.apiBaseUrl;
  String? _token;
  
  // Reusable HTTP client with connection pooling and keep-alive
  late final http.Client _httpClient;
  
  // Simple request cache for GET requests (5 minute TTL)
  final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  
  // Track last successful request time to detect cold starts
  // Fetch deviation time-series for a tractor
  Future<List<Map<String, dynamic>>> fetchDeviationTimeSeries(String tractorId) async {
    final url = Uri.parse('$baseUrl/audio/$tractorId/deviation_timeseries');
    final response = await _httpClient.get(url, headers: _getHeaders());
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['points']);
    } else {
      throw Exception('Failed to fetch deviation time-series');
    }
  }
  DateTime? _lastSuccessfulRequest;
  
  ApiService._internal() {
    _httpClient = http.Client();
  }
  
  // Clean up cache periodically
  void _cleanCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => now.difference(entry.timestamp) > _cacheTTL);
  }
  
  // Check if we should retry (for Render cold starts)
  bool _shouldRetry(int attempt, Exception? error) {
    if (attempt >= 3) return false;
    if (error == null) return false;
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('timeout') || 
           errorStr.contains('connection') ||
           errorStr.contains('failed to fetch') ||
           (_lastSuccessfulRequest == null && attempt < 2); // First request might be cold start
  }
  
  // Retry with exponential backoff
  Future<T> _retryRequest<T>(Future<T> Function() request, {int maxRetries = 3}) async {
    int attempt = 0;
    Exception? lastError;
    
    while (attempt < maxRetries) {
      try {
        final result = await request();
        _lastSuccessfulRequest = DateTime.now();
        return result;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;
        
        if (!_shouldRetry(attempt, lastError)) {
          rethrow;
        }
        
        // Exponential backoff: 1s, 2s, 4s
        final delay = Duration(seconds: 1 << (attempt - 1));
        AppConfig.log('🔄 Retry attempt $attempt/$maxRetries after ${delay.inSeconds}s...');
        await Future.delayed(delay);
      }
    }
    
    throw lastError ?? Exception('Request failed after $maxRetries attempts');
  }
  
  // Optimized GET request with caching
  Future<http.Response> _get(String url, {Map<String, String>? headers, bool useCache = true, int? timeout}) async {
    _cleanCache();
    
    // Check cache first
    if (useCache && _cache.containsKey(url)) {
      final entry = _cache[url]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheTTL) {
        AppConfig.log('💾 Cache hit for: $url');
        return entry.response;
      }
      _cache.remove(url);
    }
    
    final response = await _retryRequest(() async {
      return await _httpClient.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(Duration(seconds: timeout ?? AppConfig.quickTimeout));
    });
    
    // Cache successful GET responses
    if (useCache && response.statusCode == 200) {
      _cache[url] = _CacheEntry(response, DateTime.now());
    }
    
    return response;
  }
  
  // Optimized POST request
  Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body, int? timeout}) async {
    return await _retryRequest(() async {
      return await _httpClient.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(Duration(seconds: timeout ?? AppConfig.apiTimeout));
    });
  }
  
  // Clear cache for a specific URL or all
  void clearCache([String? url]) {
    if (url != null) {
      _cache.remove(url);
    } else {
      _cache.clear();
    }
  }
  
  // Dispose HTTP client
  void dispose() {
    _httpClient.close();
    _cache.clear();
  }

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
    final headers = AppConfig.getHeaders(token: includeAuth ? _token : null);
    // Add keep-alive for connection reuse
    headers['Connection'] = 'keep-alive';
    headers['Keep-Alive'] = 'timeout=30, max=1000';
    return headers;
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
      
      final response = await _post(
        loginUrl,
        headers: _getHeaders(includeAuth: false),
        body: json.encode({'email': email, 'password': password}),
        timeout: AppConfig.apiTimeout,
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
      final response = await _get(
        AppConfig.getApiUrl('${AppConfig.authEndpoint}/me'),
        headers: _getHeaders(),
        useCache: false, // Don't cache user data
        timeout: AppConfig.quickTimeout,
      );
      
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
      
      final response = await _get(
        tractorsUrl,
        headers: headers,
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
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
        
        // Parse tractors
        final tractors = tractorsList.map((tractorJson) => Tractor.fromJson(tractorJson)).toList();
        
        // Cache tractors for offline use
        final storage = StorageService();
        await storage.saveTractorsOffline(tractors);
        
        return tractors;
      } else {
        throw ApiException('Failed to fetch tractors: ${response.body}', response.statusCode);
      }
    } catch (e) {
      AppConfig.logError('❌ Error fetching tractors', e);
      
      // Try to load from offline cache
      try {
        final storage = StorageService();
        final cachedTractors = await storage.getTractorsOffline();
        if (cachedTractors.isNotEmpty) {
          AppConfig.log('📱 Using cached tractors data (${cachedTractors.length} tractors)');
          return cachedTractors;
        }
      } catch (cacheError) {
        AppConfig.logError('❌ Error loading cached tractors', cacheError);
      }
      
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
      
      final response = await _post(
        AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/'),
        headers: headers,
        body: json.encode(formattedData),
        timeout: AppConfig.apiTimeout,
      );
      
      // Clear cache after creating new tractor
      clearCache();
      
      AppConfig.log('📡 Create response status: ${response.statusCode}');
      AppConfig.log('📄 Create response: ${response.body}');
      
      if (response.statusCode == 201) {
        AppConfig.logSuccess('✅ Tractor created successfully!');
        return Tractor.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - Please login again');
      } else if (response.statusCode == 403) {
        throw Exception('Not authorized to create tractors');
      } else if (response.statusCode == 400) {
        // Parse validation error from backend
        try {
          final errorBody = json.decode(response.body);
          final detail = errorBody['detail'] ?? response.body;
          AppConfig.logError('❌ Validation error', detail);
          throw Exception(detail is String ? detail : 'Invalid request. Please check your input and try again.');
        } catch (e) {
          if (e is Exception && e.toString().contains('detail')) {
            rethrow;
          }
          throw Exception('Invalid request. Please check your input and try again.');
        }
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

      // Send request with timeout (multipart requests can only be sent once - don't retry)
      http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(Duration(seconds: AppConfig.uploadTimeout));
      } catch (e) {
        // If request fails, don't retry - let it be caught and queued for offline sync
        AppConfig.logError('Request send failed (will queue for offline sync)', e);
        rethrow;
      }
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
          'duration_seconds': data['duration_seconds'] ?? data['duration'],
          'baseline_comparison': data['baseline_comparison'],
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
    await ensureTokenLoaded();
    
    AppConfig.log('🔧 Fetching maintenance records for tractor: $tractorId');
    
    try {
      final url = AppConfig.getApiUrl('/maintenance/$tractorId/records');
      final response = await _get(
        url,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
      AppConfig.log('📡 Maintenance response status: ${response.statusCode}');
      AppConfig.log('📄 Maintenance response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> recordsList;
        
        if (data is List) {
          recordsList = data;
        } else if (data is Map && data['records'] != null) {
          recordsList = data['records'];
        } else {
          recordsList = [];
        }
        
        AppConfig.log('✅ Found ${recordsList.length} maintenance records');
        
        // Convert backend records to Maintenance objects
        List<Maintenance> maintenanceList = recordsList.map((record) {
          return Maintenance(
            id: record['id'] ?? '',
            tractorId: record['tractor_id'] ?? tractorId,
            userId: 'user_001', // Default user
            type: MaintenanceType.service, // Default type
            customType: record['task_name'] ?? 'Maintenance',
            triggerType: MaintenanceTriggerType.manual, // Default for completed records
            predictionId: record['prediction_id'],
            dueDate: DateTime.parse(record['completion_date'] ?? DateTime.now().toIso8601String()),
            notes: record['notes'] ?? record['description'] ?? '',
            status: MaintenanceStatus.completed, // All records from backend are completed
            completedAt: DateTime.parse(record['completion_date'] ?? DateTime.now().toIso8601String()),
            actualCost: (record['actual_cost_rwf'] ?? 0).toDouble(),
            createdAt: DateTime.parse(record['created_at'] ?? DateTime.now().toIso8601String()),
          );
        }).toList();
        
        // Filter by completed status if requested
        if (completed) {
          return maintenanceList.where((m) => m.status == MaintenanceStatus.completed).toList();
        } else {
          // For upcoming tasks, fetch from alerts endpoint
          try {
            final alertsResponse = await _get(
              '$baseUrl/maintenance/$tractorId/alerts',
              headers: _getHeaders(),
              useCache: true,
              timeout: AppConfig.quickTimeout,
            );
            
            if (alertsResponse.statusCode == 200) {
              final alertsData = jsonDecode(alertsResponse.body);
              List<Maintenance> upcomingTasks = [];
              
              if (alertsData is Map && alertsData['alerts'] is List) {
                for (var alert in alertsData['alerts']) {
                  upcomingTasks.add(Maintenance(
                    id: alert['_id'] ?? 'alert_${DateTime.now().millisecondsSinceEpoch}',
                    tractorId: tractorId,
                    userId: alert['user_id'] ?? 'system',
                    type: _mapAlertTypeToMaintenanceType(alert['alert_type']),
                    customType: alert['title'] ?? alert['alert_type'] ?? 'Maintenance',
                    triggerType: MaintenanceTriggerType.usageInterval, // Default for alerts
                    dueDate: DateTime.tryParse(alert['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
                    notes: alert['description'] ?? alert['message'] ?? 'Maintenance required',
                    status: MaintenanceStatus.upcoming,
                    createdAt: DateTime.tryParse(alert['created_at'] ?? '') ?? DateTime.now(),
                  ));
                }
              }
              
              return upcomingTasks;
            } else {
              debugPrint('Failed to fetch alerts: ${alertsResponse.statusCode}');
              return [];
            }
          } catch (e) {
            debugPrint('Error fetching alerts for upcoming maintenance: $e');
            return [];
          }
        }
      } else if (response.statusCode == 404) {
        AppConfig.log('ℹ️ No maintenance records found for tractor $tractorId');
        return [];
      }
      throw Exception('Failed to get maintenance records - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get maintenance records error', e);
      // Return empty list instead of throwing to allow UI to work
      return [];
    }
  }

  // Additional methods that were missing
  Future<Tractor> getTractor(String tractorId) async {
    final tractorUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/$tractorId');
    AppConfig.log('🚜 Fetching tractor: $tractorId');
    
    try {
      final response = await _get(
        tractorUrl,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
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
      final response = await _retryRequest(() async {
        return await _httpClient.put(
          Uri.parse(updateUrl),
          headers: _getHeaders(),
          body: json.encode(updates),
        ).timeout(Duration(seconds: AppConfig.apiTimeout));
      });
      
      // Clear cache after update
      clearCache();
      
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
      final response = await _retryRequest(() async {
        return await _httpClient.delete(
          Uri.parse('$baseUrl/tractors/$tractorId'),
          headers: _getHeaders(),
        ).timeout(Duration(seconds: AppConfig.apiTimeout));
      });
      
      // Clear cache after deletion
      clearCache();
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete tractor');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AudioPrediction>> getPredictions(String tractorId) async {
    final predictionsUrl = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/$tractorId/predictions');
    AppConfig.log('📊 Fetching predictions for tractor: $tractorId');
    
    try {
      final response = await _get(
        predictionsUrl,
        headers: _getHeaders(),
        useCache: false, // Don't cache predictions - they change frequently
        timeout: AppConfig.quickTimeout,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> predictionsList = data['predictions'] ?? data;
        
        AppConfig.log('📦 Received ${predictionsList.length} predictions from API');
        
        // Debug: Log first prediction's raw structure
        if (predictionsList.isNotEmpty) {
          final firstPred = predictionsList.first;
          AppConfig.log('🔍 First prediction structure:');
          AppConfig.log('   - Has baseline_deviation: ${firstPred['baseline_deviation'] != null}');
          AppConfig.log('   - Has baseline_comparison: ${firstPred['baseline_comparison'] != null}');
          if (firstPred['baseline_comparison'] != null) {
            AppConfig.log('   - baseline_comparison.deviation_score: ${firstPred['baseline_comparison']['deviation_score']}');
            AppConfig.log('   - baseline_comparison.has_baseline: ${firstPred['baseline_comparison']['has_baseline']}');
          }
        }
        
        return predictionsList.map((json) {
          // Normalize the JSON to ensure baseline_comparison is properly handled
          final normalized = Map<String, dynamic>.from(json);
          // Ensure baseline_comparison is preserved
          if (json['baseline_comparison'] != null) {
            normalized['baseline_comparison'] = json['baseline_comparison'];
          }
          return AudioPrediction.fromJson(normalized);
        }).toList();
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

      // Send request with timeout (multipart requests can only be sent once - don't retry)
      http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(Duration(seconds: AppConfig.uploadTimeout));
      } catch (e) {
        // If request fails, don't retry - let it be caught and queued for offline sync
        AppConfig.logError('Request send failed (will queue for offline sync)', e);
        rethrow;
      }
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
          'duration_seconds': data['duration_seconds'] ?? data['duration'],
          'baseline_comparison': data['baseline_comparison'],
        };
        return AudioPrediction.fromJson(normalized);
      } else {
        throw Exception('Audio upload failed: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Audio upload error', e);
      
      // Store for offline sync if network error
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Connection failed')) {
        
        AppConfig.log('📱 Storing audio for offline sync');
        final storage = StorageService();
        final pendingItems = await storage.getPendingSyncItems();
        
        // Store audio bytes in base64 for offline sync
        final audioId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
        final base64Audio = base64Encode(bytes);
        
        pendingItems.add({
          'type': 'audio_upload',
          'tractor_id': tractorId,
          'engine_hours': engineHours,
          'filename': filename,
          'audio_data': base64Audio,
          'timestamp': DateTime.now().toIso8601String(),
          'id': audioId,
        });
        
        await storage.savePendingSyncItems(pendingItems);
        AppConfig.log('✅ Audio stored for offline sync');
        
        // Return a mock prediction for offline mode
        return AudioPrediction.fromJson({
          'id': audioId,
          'tractor_id': tractorId,
          'prediction_class': 'offline_pending',
          'confidence': 0.0,
          'anomaly_score': 0.0,
          'audio_path': 'offline_pending',
          'created_at': DateTime.now().toIso8601String(),
          'duration_seconds': 0.0,
          'baseline_comparison': null,
          'offline': true,
        });
      }
      
      rethrow;
    }
  }

  Future<AudioPrediction> getPrediction(String predictionId) async {
    final predictionUrl = AppConfig.getApiUrl('${AppConfig.audioEndpoint}/predictions/$predictionId');
    AppConfig.log('🎵 Fetching prediction: $predictionId');
    
    try {
      final response = await _get(
        predictionUrl,
        headers: _getHeaders(),
        useCache: false,
        timeout: AppConfig.quickTimeout,
      );
      
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
      final response = await _retryRequest(() async {
        return await _httpClient.delete(
          Uri.parse(url),
          headers: _getHeaders(),
        ).timeout(Duration(seconds: AppConfig.apiTimeout));
      });
      
      // Clear cache after deletion
      clearCache();

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
    await ensureTokenLoaded();
    
    AppConfig.log('🔧 Updating maintenance: $maintenanceId');
    
    try {
      // Try to use the updateMaintenanceRecord endpoint if available
      final response = await updateMaintenanceRecord(maintenanceId, updates);
      
      // Convert response to Maintenance object
      final now = DateTime.now();
      return Maintenance(
        id: maintenanceId,
        tractorId: response['tractor_id'] ?? updates['tractor_id'] ?? 'unknown',
        userId: response['user_id'] ?? updates['user_id'] ?? 'user_001',
        type: MaintenanceType.service,
        customType: response['task_name'] ?? updates['custom_type'] ?? 'Updated Service',
        triggerType: MaintenanceTriggerType.manual,
        dueDate: response['due_date'] != null 
          ? DateTime.parse(response['due_date'])
          : (updates['due_date'] != null ? DateTime.parse(updates['due_date']) : now.add(const Duration(days: 30))),
        notes: response['notes'] ?? updates['notes'],
        status: response['status'] != null
          ? MaintenanceStatus.values.firstWhere(
              (status) => status.toString().split('.').last == response['status'],
              orElse: () => MaintenanceStatus.upcoming,
            )
          : (updates['status'] != null
            ? MaintenanceStatus.values.firstWhere(
                (status) => status.toString().split('.').last == updates['status'],
                orElse: () => MaintenanceStatus.upcoming,
              )
            : MaintenanceStatus.upcoming),
        completedAt: response['completed_at'] != null ? DateTime.parse(response['completed_at']) : (updates['completed_at'] != null ? DateTime.parse(updates['completed_at']) : null),
        actualCost: (response['actual_cost_rwf'] ?? updates['actual_cost'] ?? 0).toDouble(),
        createdAt: response['created_at'] != null ? DateTime.parse(response['created_at']) : now.subtract(const Duration(days: 1)),
      );
    } catch (e) {
      AppConfig.logError('❌ Update maintenance error', e);
      
      // Check if this is a network error - queue for offline sync
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Connection failed') ||
          e.toString().contains('SocketException')) {
        
        AppConfig.log('📱 Queueing maintenance update for offline sync');
        final storage = StorageService();
        final pendingItems = await storage.getPendingSyncItems();
        
        final updateId = 'maintenance_update_${DateTime.now().millisecondsSinceEpoch}';
        pendingItems.add({
          'type': 'maintenance_update',
          'maintenance_id': maintenanceId,
          'updates': updates,
          'timestamp': DateTime.now().toIso8601String(),
          'id': updateId,
          'pending_sync_id': updateId,
        });
        
        await storage.savePendingSyncItems(pendingItems);
        AppConfig.log('✅ Maintenance update queued for offline sync');
        
        // Return a mock updated maintenance object for offline mode
        final now = DateTime.now();
        return Maintenance(
          id: maintenanceId,
          tractorId: updates['tractor_id'] ?? 'unknown',
          userId: updates['user_id'] ?? 'user_001',
          type: MaintenanceType.service,
          customType: updates['custom_type'] ?? 'Updated Service',
          triggerType: MaintenanceTriggerType.manual,
          dueDate: updates['due_date'] != null ? DateTime.parse(updates['due_date']) : now.add(const Duration(days: 30)),
          notes: updates['notes'],
          status: updates['status'] != null
            ? MaintenanceStatus.values.firstWhere(
                (status) => status.toString().split('.').last == updates['status'],
                orElse: () => MaintenanceStatus.upcoming,
              )
            : MaintenanceStatus.upcoming,
          completedAt: updates['completed_at'] != null ? DateTime.parse(updates['completed_at']) : null,
          estimatedCost: updates['estimated_cost']?.toDouble() ?? 0.0,
          createdAt: updates['created_at'] != null ? DateTime.parse(updates['created_at']) : now,
        );
      }
      
      rethrow;
    }
  }

  Future<void> deleteMaintenance(String maintenanceId) async {
    AppConfig.log('🗑️ Deleting maintenance: $maintenanceId (mock operation)');
    
    // TODO: Replace with actual API call when backend endpoint is implemented
    // For now, simulate successful deletion
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate network delay
    AppConfig.logSuccess('✅ Maintenance deleted successfully (mock)');
  }

  Future<Maintenance> createMaintenance(Map<String, dynamic> maintenanceData) async {
    await ensureTokenLoaded();
    
    AppConfig.log('🔧 Recording completed maintenance task');
    
    try {
      final tractorId = maintenanceData['tractor_id'] ?? '';
      final url = AppConfig.getApiUrl('/maintenance/$tractorId/records');
      
      // Format data for backend API
      final requestData = {
        'task_name': maintenanceData['task_name'] ?? maintenanceData['custom_type'] ?? 'Maintenance Task',
        'description': maintenanceData['description'] ?? maintenanceData['notes'] ?? '',
        'completion_date': maintenanceData['completion_date'] ?? DateTime.now().toIso8601String(),
        'completion_hours': maintenanceData['completion_hours'] ?? 1,
        'actual_time_minutes': maintenanceData['actual_time_minutes'] ?? 30,
        'actual_cost_rwf': maintenanceData['actual_cost_rwf'] ?? maintenanceData['actual_cost'] ?? 0,
        'service_location': maintenanceData['service_location'] ?? '',
        'service_provider': maintenanceData['service_provider'] ?? '',
        'notes': maintenanceData['notes'] ?? '',
        'performed_by': maintenanceData['performed_by'] ?? '',
        'parts_used': maintenanceData['parts_used'] ?? [],
      };
      
      AppConfig.log('📊 Request data: $requestData');
      
      final response = await _post(
        url,
        headers: _getHeaders(),
        body: json.encode(requestData),
        timeout: AppConfig.apiTimeout,
      );
      
      // Clear cache after maintenance changes
      clearCache();
      
      AppConfig.log('📡 Create maintenance response status: ${response.statusCode}');
      AppConfig.log('📄 Create maintenance response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        AppConfig.logSuccess('✅ Maintenance recorded successfully');
        
        // Convert response back to Maintenance object
        return Maintenance(
          id: responseData['id'] ?? '',
          tractorId: responseData['tractor_id'] ?? tractorId,
          userId: 'user_001', // Default user
          type: MaintenanceType.service,
          customType: responseData['task_name'] ?? 'Maintenance',
          triggerType: MaintenanceTriggerType.manual, // Default for completed maintenance
          dueDate: DateTime.parse(responseData['completion_date'] ?? DateTime.now().toIso8601String()),
          notes: responseData['notes'] ?? '',
          status: MaintenanceStatus.completed,
          completedAt: DateTime.parse(responseData['completion_date'] ?? DateTime.now().toIso8601String()),
          actualCost: (responseData['actual_cost_rwf'] ?? 0).toDouble(),
          createdAt: DateTime.parse(responseData['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }
      throw Exception('Failed to record maintenance - Status: ${response.statusCode}: ${response.body}');
    } catch (e) {
      AppConfig.logError('❌ Create maintenance error', e);
      
      // Check if this is a network error - queue for offline sync
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Connection failed') ||
          e.toString().contains('SocketException')) {
        
        AppConfig.log('📱 Queueing maintenance record for offline sync');
        final storage = StorageService();
        final pendingItems = await storage.getPendingSyncItems();
        
        final maintenanceId = 'maintenance_${DateTime.now().millisecondsSinceEpoch}';
        pendingItems.add({
          'type': 'maintenance_record',
          'tractor_id': maintenanceData['tractor_id'] ?? '',
          'task_name': maintenanceData['task_name'] ?? maintenanceData['custom_type'] ?? 'Maintenance Task',
          'description': maintenanceData['description'] ?? maintenanceData['notes'] ?? '',
          'completion_date': maintenanceData['completion_date'] ?? DateTime.now().toIso8601String(),
          'completion_hours': maintenanceData['completion_hours'] ?? 1,
          'actual_time_minutes': maintenanceData['actual_time_minutes'] ?? 30,
          'actual_cost_rwf': maintenanceData['actual_cost_rwf'] ?? maintenanceData['actual_cost'] ?? 0,
          'service_location': maintenanceData['service_location'] ?? '',
          'service_provider': maintenanceData['service_provider'] ?? '',
          'notes': maintenanceData['notes'] ?? '',
          'performed_by': maintenanceData['performed_by'] ?? '',
          'parts_used': maintenanceData['parts_used'] ?? [],
          'timestamp': DateTime.now().toIso8601String(),
          'id': maintenanceId,
          'pending_sync_id': maintenanceId,
        });
        
        await storage.savePendingSyncItems(pendingItems);
        AppConfig.log('✅ Maintenance record queued for offline sync');
        
        // Return a mock maintenance object for offline mode
        return Maintenance(
          id: maintenanceId,
          tractorId: maintenanceData['tractor_id'] ?? '',
          userId: 'user_001',
          type: MaintenanceType.service,
          customType: maintenanceData['task_name'] ?? maintenanceData['custom_type'] ?? 'Maintenance Task',
          triggerType: MaintenanceTriggerType.manual,
          dueDate: DateTime.parse(maintenanceData['completion_date'] ?? DateTime.now().toIso8601String()),
          notes: maintenanceData['notes'] ?? '',
          status: MaintenanceStatus.completed,
          completedAt: DateTime.parse(maintenanceData['completion_date'] ?? DateTime.now().toIso8601String()),
          actualCost: (maintenanceData['actual_cost_rwf'] ?? maintenanceData['actual_cost'] ?? 0).toDouble(),
          createdAt: DateTime.now(),
        );
      }
      
      rethrow;
    }
  }

  // Create a new maintenance task (not completed maintenance)
  Future<Maintenance> createMaintenanceTask(Map<String, dynamic> taskData) async {
    await ensureTokenLoaded();
    
    AppConfig.log('🔧 Creating new maintenance task');
    
    try {
      final tractorId = taskData['tractor_id'] ?? '';
      final url = AppConfig.getApiUrl('/maintenance/$tractorId/test-alert');
      
      AppConfig.log('🔧 Creating maintenance alert for abnormal sound');
      AppConfig.log('🌐 Posting to URL: $url');
      
      final response = await _post(
        url,
        headers: _getHeaders(),
        body: null,
        timeout: AppConfig.apiTimeout,
      );
      
      // Clear cache after creating maintenance task
      clearCache();
      
      AppConfig.log('📡 Create task response status: ${response.statusCode}');
      AppConfig.log('📄 Create task response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        AppConfig.logSuccess('✅ Maintenance task created successfully');
        
        // Convert response to Maintenance object
        return Maintenance(
          id: responseData['alert_id'] ?? '',
          tractorId: responseData['tractor_id'] ?? tractorId,
          userId: 'user_001', // Default user
          type: MaintenanceType.inspection,
          customType: 'Sound Analysis Inspection',
          triggerType: MaintenanceTriggerType.abnormalSound, // This is from sound analysis
          dueDate: DateTime.now().add(const Duration(days: 1)),
          notes: 'Automatically generated alert due to abnormal sound detection',
          status: MaintenanceStatus.upcoming,
          estimatedCost: 0.0,
          createdAt: DateTime.now(),
        );
      } else if (response.statusCode == 404) {
        throw Exception('Maintenance task endpoint not found (404) - may not be deployed yet');
      } else if (response.statusCode == 422) {
        throw Exception('Invalid task data (422): ${response.body}');
      } else {
        throw Exception('Failed to create maintenance task - Status: ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      AppConfig.logError('❌ Create maintenance task error', e);
      
      // Check if this is a network error - queue for offline sync
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('Connection failed') ||
          e.toString().contains('SocketException')) {
        
        AppConfig.log('📱 Queueing maintenance task for offline sync');
        final storage = StorageService();
        final pendingItems = await storage.getPendingSyncItems();
        
        final taskId = 'maintenance_task_${DateTime.now().millisecondsSinceEpoch}';
        pendingItems.add({
          'type': 'maintenance_task',
          'tractor_id': taskData['tractor_id'] ?? '',
          'task_data': taskData,
          'timestamp': DateTime.now().toIso8601String(),
          'id': taskId,
          'pending_sync_id': taskId,
        });
        
        await storage.savePendingSyncItems(pendingItems);
        AppConfig.log('✅ Maintenance task queued for offline sync');
        
        // Return a mock maintenance object for offline mode
        return Maintenance(
          id: taskId,
          tractorId: taskData['tractor_id'] ?? '',
          userId: 'user_001',
          type: MaintenanceType.inspection,
          customType: taskData['custom_type'] ?? taskData['type'] ?? 'Maintenance Task',
          triggerType: MaintenanceTriggerType.manual,
          dueDate: taskData['due_date'] != null ? DateTime.parse(taskData['due_date']) : DateTime.now().add(const Duration(days: 30)),
          notes: taskData['notes'] ?? '',
          status: MaintenanceStatus.upcoming,
          estimatedCost: (taskData['estimated_cost'] ?? 0).toDouble(),
          createdAt: DateTime.now(),
        );
      }
      
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String fullName) async {
    final registerUrl = AppConfig.getApiUrl('${AppConfig.authEndpoint}/register');
    AppConfig.log('📝 Attempting registration to: $registerUrl');
    AppConfig.log('📧 Email: $email');
    
    try {
      final response = await _post(
        registerUrl,
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
        timeout: AppConfig.apiTimeout,
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
      final response = await _post(
        url,
        headers: _getHeaders(),
        body: null,
        timeout: AppConfig.apiTimeout,
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

      // Send request with timeout (don't retry multipart requests - they can't be retried)
      final streamedResponse = await request.send().timeout(Duration(seconds: AppConfig.uploadTimeout));
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
      
      final response = await _post(
        url,
        headers: _getHeaders(),
        body: null,
        timeout: 30, // Increased timeout for baseline finalization (can take longer due to ML processing)
      );
      
      // Clear cache after baseline changes
      clearCache();

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
      final response = await _get(
        url,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
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
      final response = await _get(
        url,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
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
      final response = await _post(
        '$baseUrl${AppConfig.usageEndpoint}/$tractorId/log',
        headers: _getHeaders(),
        body: json.encode({
          'end_hours': endHours,
          'notes': notes,
        }),
        timeout: AppConfig.apiTimeout,
      );
      
      // Clear cache after logging usage
      clearCache();
      
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
      
      final response = await _get(
        uri.toString(),
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
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
    await ensureTokenLoaded();
    
    AppConfig.log('🔧 Fetching maintenance alerts for tractor: $tractorId');
    
    try {
      final url = AppConfig.getApiUrl('/maintenance/$tractorId/alerts');
      final response = await _get(
        url,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
      AppConfig.log('📡 Alerts response status: ${response.statusCode}');
      AppConfig.log('📄 Alerts response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> alertsList;
        
        if (data is List) {
          alertsList = data;
        } else if (data is Map && data['alerts'] != null) {
          alertsList = data['alerts'];
        } else {
          alertsList = [];
        }
        
        AppConfig.log('✅ Found ${alertsList.length} maintenance alerts');
        return alertsList;
      } else if (response.statusCode == 404) {
        AppConfig.log('ℹ️ No maintenance alerts found for tractor $tractorId');
        return [];
      }
      throw Exception('Failed to get maintenance alerts - Status: ${response.statusCode}');
    } catch (e) {
      AppConfig.logError('❌ Get maintenance alerts error', e);
      // Return empty list instead of throwing to allow UI to work
      return [];
    }
  }

  Future<TractorSummary> getTractorSummary(String tractorId) async {
    await ensureTokenLoaded();
    
    final summaryUrl = AppConfig.getApiUrl('${AppConfig.tractorsEndpoint}/$tractorId/summary');
    AppConfig.log('📊 Fetching tractor summary: $tractorId from $summaryUrl');
    
    try {
      final response = await _get(
        summaryUrl,
        headers: _getHeaders(),
        useCache: true,
        timeout: AppConfig.quickTimeout,
      );
      
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

  // ==================== USAGE LOG METHODS ====================

  Future<Map<String, dynamic>> addUsageLog(String tractorId, Map<String, dynamic> usageData) async {
    await ensureTokenLoaded();
    AppConfig.log('📝 Adding usage log for tractor: $tractorId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tractors/$tractorId/usage'),
        headers: _getHeaders(),
        body: json.encode(usageData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        AppConfig.log('✅ Usage log added successfully');
        return data;
      } else {
        AppConfig.logError('❌ Failed to add usage log', 'Status: ${response.statusCode}');
        throw ApiException('Failed to add usage log: ${response.body}', response.statusCode);
      }
    } catch (e) {
      AppConfig.logError('❌ Usage log API error', e);
      
      // Store for offline sync if network error
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('TimeoutException')) {
        
        AppConfig.log('📱 Storing usage log for offline sync');
        final storage = StorageService();
        final pendingItems = await storage.getPendingSyncItems();
        
        pendingItems.add({
          'type': 'usage_log',
          'tractor_id': tractorId,
          'data': usageData,
          'timestamp': DateTime.now().toIso8601String(),
          'id': 'usage_${DateTime.now().millisecondsSinceEpoch}',
        });
        
        await storage.savePendingSyncItems(pendingItems);
        AppConfig.log('✅ Usage log stored for offline sync');
        
        return {
          'success': true,
          'message': 'Usage log saved offline and will sync when connection is restored',
          'offline': true,
        };
      }
      
      rethrow;
    }
  }

  // ==================== MAINTENANCE RECORD METHODS ====================

  Future<Map<String, dynamic>> addMaintenanceRecord(String tractorId, Map<String, dynamic> maintenanceData) async {
    await ensureTokenLoaded();
    AppConfig.log('🔧 Adding maintenance record for tractor: $tractorId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/maintenance'),
        headers: _getHeaders(),
        body: json.encode({
          'tractor_id': tractorId,
          ...maintenanceData,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        AppConfig.log('✅ Maintenance record added successfully');
        return data;
      } else {
        AppConfig.logError('❌ Failed to add maintenance record', 'Status: ${response.statusCode}');
        throw ApiException('Failed to add maintenance record: ${response.body}', response.statusCode);
      }
    } catch (e) {
      AppConfig.logError('❌ Maintenance record API error', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateMaintenanceRecord(String maintenanceId, Map<String, dynamic> updates) async {
    await ensureTokenLoaded();
    AppConfig.log('🔧 Updating maintenance record: $maintenanceId');

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/maintenance/$maintenanceId'),
        headers: _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppConfig.log('✅ Maintenance record updated successfully');
        return data;
      } else {
        AppConfig.logError('❌ Failed to update maintenance record', 'Status: ${response.statusCode}');
        throw ApiException('Failed to update maintenance record: ${response.body}', response.statusCode);
      }
    } catch (e) {
      AppConfig.logError('❌ Maintenance update API error', e);
      rethrow;
    }
  }

  // Helper method to map alert types to maintenance types
  MaintenanceType _mapAlertTypeToMaintenanceType(String? alertType) {
    switch (alertType?.toLowerCase()) {
      case 'audio_anomaly':
      case 'abnormal_sound':
        return MaintenanceType.repair;
      case 'oil_change':
        return MaintenanceType.service;
      case 'filter_replacement':
        return MaintenanceType.service;
      case 'inspection':
        return MaintenanceType.inspection;
      case 'service':
        return MaintenanceType.service;
      default:
        return MaintenanceType.service;
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

// Cache entry for GET request caching
class _CacheEntry {
  final http.Response response;
  final DateTime timestamp;
  
  _CacheEntry(this.response, this.timestamp);
}
