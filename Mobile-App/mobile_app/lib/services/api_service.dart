// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/tractor.dart';
import '../models/maintenance_alert.dart';

class ApiService {
  // Change this based on where you're running
  // For Chrome web: use localhost
  static const String baseUrl = 'http://localhost:8000';
  
  // For Android emulator: use 'http://10.0.2.2:8000'
  // For real device: use 'http://YOUR_COMPUTER_IP:8000'

  // Get rule-based predictions
  Future<List<MaintenanceAlert>> getRuleBasedPredictions(Tractor tractor) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict/rule-based'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(tractor.toJson()),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => MaintenanceAlert.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load predictions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching predictions: $e');
      // Return mock data for offline demo
      return _getMockAlerts();
    }
  }

  // Upload audio for ML prediction
  Future<Map<String, dynamic>> uploadAudio(File audioFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict/ml-audio'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('audio_file', audioFile.path),
      );

      var streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to upload audio: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading audio: $e');
      // Return mock prediction for offline demo
      return {
        'prediction_class': 'normal',
        'confidence': 0.85,
        'probabilities': {'normal': 0.85, 'abnormal': 0.15},
        'model_used': 'CNN (Demo Mode)'
      };
    }
  }

  // Combined prediction (rule-based + ML)
  Future<Map<String, dynamic>> getCombinedPrediction(
    Tractor tractor,
    File? audioFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict/combined'),
      );

      // Add tractor info as fields
      request.fields['tractor_info'] = jsonEncode(tractor.toJson());

      // Add audio file if provided
      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('audio_file', audioFile.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get combined prediction');
      }
    } catch (e) {
      print('Error getting combined prediction: $e');
      rethrow;
    }
  }

  // Mock data for offline testing/demo
  List<MaintenanceAlert> _getMockAlerts() {
    return [
      MaintenanceAlert(
        taskName: 'engine_oil_change',
        description: 'Engine oil and filter change',
        status: 'urgent',
        urgencyLevel: 4,
        priority: 'high',
        hoursRemaining: 20,
        daysRemaining: 7,
        estimatedCostRwf: 25000,
        recommendation: 'URGENT: Due within 20h or 7d',
      ),
      MaintenanceAlert(
        taskName: 'air_filter_check',
        description: 'Air filter inspection and cleaning',
        status: 'due_soon',
        urgencyLevel: 3,
        priority: 'medium',
        hoursRemaining: 45,
        daysRemaining: 15,
        estimatedCostRwf: 5000,
        recommendation: 'DUE SOON: Plan within 45h or 15d',
      ),
      MaintenanceAlert(
        taskName: 'fuel_filter_replace',
        description: 'Fuel filter replacement',
        status: 'approaching',
        urgencyLevel: 2,
        priority: 'high',
        hoursRemaining: 80,
        daysRemaining: 30,
        estimatedCostRwf: 12000,
        recommendation: 'OK: Next service in 80h or 30d',
      ),
      MaintenanceAlert(
        taskName: 'hydraulic_oil_change',
        description: 'Hydraulic oil and filter change',
        status: 'overdue',
        urgencyLevel: 5,
        priority: 'high',
        hoursRemaining: 0,
        daysRemaining: 0,
        estimatedCostRwf: 35000,
        recommendation: 'OVERDUE: Schedule maintenance immediately',
      ),
    ];
  }
}