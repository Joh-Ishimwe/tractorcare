import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/tractor.dart';
import '../models/prediction.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
    ),
  );
  
  ApiService() {
    // Add interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          print('API Error: ${error.response?.statusCode} - ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }
  
  // Get tractors for cooperative
  Future<List<Tractor>> getTractors(String coopId) async {
    try {
      final response = await _dio.get('/cooperatives/$coopId/tractors');
      
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => Tractor.fromJson(json)).toList();
      }
      throw Exception('Failed to load tractors');
    } catch (e) {
      print('Error fetching tractors: $e');
      rethrow;
    }
  }
  
  // Get single tractor
  Future<Tractor> getTractor(String tractorId) async {
    final response = await _dio.get('/tractors/$tractorId');
    return Tractor.fromJson(response.data);
  }
  
  // Get maintenance predictions
  Future<List<MaintenancePrediction>> getPredictions(String tractorId) async {
    try {
      final response = await _dio.post('/predict/rule-based/$tractorId');
      
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => MaintenancePrediction.fromJson(json)).toList();
      }
      throw Exception('Failed to load predictions');
    } catch (e) {
      print('Error fetching predictions: $e');
      rethrow;
    }
  }
  
  // Upload audio for ML prediction
  Future<Map<String, dynamic>> uploadAudio(String tractorId, File audioFile) async {
    try {
      FormData formData = FormData.fromMap({
        'audio_file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'engine_sound.wav',
        ),
      });
      
      final response = await _dio.post(
        '/predict/ml-audio/$tractorId',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      
      return response.data;
    } catch (e) {
      print('Error uploading audio: $e');
      rethrow;
    }
  }
  
  // Create booking
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    final response = await _dio.post('/bookings', data: bookingData);
    return response.data;
  }
  
  // Get bookings for tractor
  Future<List<dynamic>> getTractorBookings(String tractorId) async {
    final response = await _dio.get('/tractors/$tractorId/bookings');
    return response.data;
  }
  
  // Log maintenance
  Future<Map<String, dynamic>> logMaintenance(Map<String, dynamic> maintenanceData) async {
    final response = await _dio.post('/maintenance/records', data: maintenanceData);
    return response.data;
  }
  
  // Get maintenance history
  Future<List<dynamic>> getMaintenanceHistory(String tractorId) async {
    final response = await _dio.get('/tractors/$tractorId/maintenance/history');
    return response.data;
  }
  
  // Get dashboard stats
  Future<Map<String, dynamic>> getDashboardStats(String coopId) async {
    final response = await _dio.get('/cooperatives/$coopId/dashboard');
    return response.data;
  }
}