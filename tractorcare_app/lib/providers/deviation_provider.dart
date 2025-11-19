// lib/providers/deviation_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/audio_prediction.dart';
import '../models/deviation_point.dart';
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';
import '../config/app_config.dart';

class DeviationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  String? _currentTractorId;

  List<DeviationPoint> _deviationPoints = [];
  DateTime? _baselineDate;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Baseline metadata
  String? _baselineId;
  double? _baselineConfidence;
  int? _baselineNumSamples;
  double? _baselineTractorHours;
  String? _baselineLoadCondition;

  DeviationProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen to connectivity changes to refresh data after sync
    _offlineSyncService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    // When connection is restored and we have a current tractor, refresh data
    if (_offlineSyncService.isOnline && _currentTractorId != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        AppConfig.log('📶 DeviationProvider: Connection restored, refreshing data for $_currentTractorId');
        fetchDeviationData(_currentTractorId!);
      });
    }
  }

  @override
  void dispose() {
    _offlineSyncService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  // Getters
  List<DeviationPoint> get deviationPoints => _deviationPoints;
  DateTime? get baselineDate => _baselineDate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasData => _deviationPoints.isNotEmpty;
  
  // Baseline metadata getters
  String? get baselineId => _baselineId;
  double? get baselineConfidence => _baselineConfidence;
  int? get baselineNumSamples => _baselineNumSamples;
  double? get baselineTractorHours => _baselineTractorHours;
  String? get baselineLoadCondition => _baselineLoadCondition;
  bool get hasBaselineInfo => _baselineId != null;

  // Get sorted deviation points by date
  List<DeviationPoint> get sortedDeviationPoints {
    final sorted = List<DeviationPoint>.from(_deviationPoints);
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  // Get deviation points with days since baseline
  List<DeviationPoint> get deviationPointsWithDays {
    if (_baselineDate == null) return sortedDeviationPoints;
    
    return sortedDeviationPoints.map((point) {
      final daysSince = point.date.difference(_baselineDate!).inDays;
      return DeviationPoint(
        date: point.date,
        deviation: point.deviation,
        engineHours: point.engineHours,
        predictionId: point.predictionId,
        baselineStatus: point.baselineStatus,
      );
    }).toList();
  }

  // Fetch deviation data for a tractor
  Future<void> fetchDeviationData(String tractorId) async {
    _currentTractorId = tractorId; // Store current tractor ID for refresh on connectivity change
    _setLoading(true);
    _setErrorMessage(null);

    try {
      // Fetch predictions first (main data we need) - use longer timeout
      List<AudioPrediction> predictions;
      try {
        predictions = await _apiService.getPredictions(tractorId).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException('Predictions request timed out after 20 seconds');
          },
        );
      } catch (e) {
        AppConfig.logError('❌ Failed to fetch predictions', e);
        // If predictions fail, we can't show deviation data
        throw Exception('Failed to load audio predictions. Please check your connection and try again.');
      }
      
      AppConfig.log('📊 Fetched ${predictions.length} total predictions');
      
      // Debug: Log details about each prediction
      for (var i = 0; i < predictions.length && i < 5; i++) {
        final p = predictions[i];
        AppConfig.log('   Prediction ${i + 1}:');
        AppConfig.log('     - ID: ${p.id}');
        AppConfig.log('     - Created: ${p.createdAt}');
        AppConfig.log('     - Baseline Deviation: ${p.baselineDeviation}');
        AppConfig.log('     - Baseline Status: ${p.baselineStatus}');
        AppConfig.log('     - Anomaly Score: ${p.anomalyScore}');
      }
      
      // Filter predictions that have baseline deviation
      final predictionsWithDeviation = predictions
          .where((p) => p.baselineDeviation != null)
          .toList();

      AppConfig.log('📈 Found ${predictionsWithDeviation.length} predictions with baseline deviation');
      
      if (predictionsWithDeviation.isEmpty && predictions.isNotEmpty) {
        AppConfig.log('⚠️ No predictions have baseline deviation. This may mean:');
        AppConfig.log('   1. No baseline has been established for this tractor');
        AppConfig.log('   2. Predictions were made before baseline was created');
        AppConfig.log('   3. Backend did not calculate baseline deviation');
        AppConfig.log('   4. Predictions need to be re-fetched after baseline is created');
        
        // Check if we have baseline info
        if (_baselineId != null) {
          AppConfig.log('   ℹ️ Baseline exists (ID: $_baselineId), but predictions don\'t have deviation');
          AppConfig.log('   💡 Try recording a new audio test - it should include baseline deviation');
        }
      }

      // Convert predictions to deviation points
      _deviationPoints = predictionsWithDeviation.map((prediction) {
        return DeviationPoint(
          date: prediction.createdAt,
          deviation: prediction.baselineDeviation!,
          engineHours: prediction.engineHours,
          predictionId: prediction.id,
          baselineStatus: prediction.baselineStatus,
        );
      }).toList();

      // Sort by date
      _deviationPoints.sort((a, b) => a.date.compareTo(b.date));

      // Try to fetch baseline date (non-blocking - don't fail if this times out)
      _tryFetchBaselineDate(tractorId);

      AppConfig.log('✅ Loaded ${_deviationPoints.length} deviation points');
      
      if (_baselineDate != null) {
        AppConfig.log('📅 Baseline date: $_baselineDate');
      } else {
        AppConfig.log('⚠️ No baseline date found (will use first prediction date as reference)');
        // Use first prediction date as fallback baseline date
        if (_deviationPoints.isNotEmpty) {
          _baselineDate = _deviationPoints.first.date;
        }
      }

      _setLoading(false);
    } catch (e) {
      AppConfig.logError('❌ Failed to fetch deviation data', e);
      String errorMessage = 'Failed to load deviation data';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to load deviation data: ${e.toString()}';
      }
      _setErrorMessage(errorMessage);
      _setLoading(false);
    }
  }

  // Try to fetch baseline date and metadata (non-blocking, won't throw)
  Future<void> _tryFetchBaselineDate(String tractorId) async {
    try {
      // Fetch baseline status with timeout
      final baselineStatus = await _apiService.getBaselineStatus(tractorId).timeout(
        const Duration(seconds: 10),
        onTimeout: () => <String, dynamic>{},
      );
      
      if (baselineStatus.isEmpty) {
        // Timeout or empty response, try history
        await _tryFetchBaselineFromHistory(tractorId);
        return;
      }

      final baselineStatusStr = baselineStatus['status']?.toString().toLowerCase() ?? 
                                baselineStatus['baseline_status']?.toString().toLowerCase();
      
      if (baselineStatusStr == 'completed' || baselineStatusStr == 'active') {
        // Extract baseline metadata
        _baselineId = baselineStatus['baseline_id']?.toString();
        _baselineConfidence = _parseDouble(baselineStatus['confidence']);
        _baselineNumSamples = baselineStatus['num_samples'] is int 
            ? baselineStatus['num_samples'] 
            : (baselineStatus['num_samples'] != null 
                ? int.tryParse(baselineStatus['num_samples'].toString()) 
                : null);
        _baselineTractorHours = _parseDouble(baselineStatus['tractor_hours']);
        _baselineLoadCondition = baselineStatus['load_condition']?.toString();
        
        // Try to get baseline creation date
        final baselineCreatedAt = baselineStatus['created_at'] ?? baselineStatus['finalized_at'];
        if (baselineCreatedAt != null) {
          _baselineDate = DateTime.parse(baselineCreatedAt.toString());
        }
        
        AppConfig.log('📊 Baseline metadata loaded:');
        AppConfig.log('   - ID: $_baselineId');
        AppConfig.log('   - Confidence: $_baselineConfidence');
        AppConfig.log('   - Samples: $_baselineNumSamples');
        AppConfig.log('   - Tractor Hours: $_baselineTractorHours');
        AppConfig.log('   - Load Condition: $_baselineLoadCondition');
        AppConfig.log('   - Date: $_baselineDate');
        
        notifyListeners();
        return;
      }
      
      // If no date in status, try baseline history
      await _tryFetchBaselineFromHistory(tractorId);
    } catch (e) {
      AppConfig.logError('Could not fetch baseline status', e);
      // Try history as fallback
      await _tryFetchBaselineFromHistory(tractorId);
    }
  }
  
  // Helper to parse double values
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Try to fetch baseline date and metadata from history (non-blocking, won't throw)
  Future<void> _tryFetchBaselineFromHistory(String tractorId) async {
    try {
      final baselineHistory = await _apiService.getBaselineHistory(tractorId).timeout(
        const Duration(seconds: 10),
        onTimeout: () => <String, dynamic>{},
      );
      
      if (baselineHistory.isEmpty) return;

      Map<String, dynamic>? activeBaseline;
      
      // Check if there's a baseline in history
      if (baselineHistory['history'] != null && (baselineHistory['history'] as List).isNotEmpty) {
        // Get the most recent active baseline
        final history = baselineHistory['history'] as List;
        activeBaseline = history.firstWhere(
          (b) => b['status'] == 'active' || b['status'] == 'completed',
          orElse: () => history.first,
        ) as Map<String, dynamic>?;
      } else if (baselineHistory['baseline'] != null) {
        // Fallback to direct baseline object
        activeBaseline = baselineHistory['baseline'] as Map<String, dynamic>?;
      }
      
      if (activeBaseline != null) {
        // Extract baseline metadata
        _baselineId = activeBaseline['baseline_id']?.toString() ?? 
                     activeBaseline['id']?.toString();
        _baselineConfidence = _parseDouble(activeBaseline['confidence']);
        _baselineNumSamples = activeBaseline['num_samples'] is int 
            ? activeBaseline['num_samples'] 
            : (activeBaseline['num_samples'] != null 
                ? int.tryParse(activeBaseline['num_samples'].toString()) 
                : null);
        _baselineTractorHours = _parseDouble(activeBaseline['tractor_hours']);
        _baselineLoadCondition = activeBaseline['load_condition']?.toString();
        
        final createdAt = activeBaseline['created_at'] ?? activeBaseline['finalized_at'];
        if (createdAt != null) {
          _baselineDate = DateTime.parse(createdAt.toString());
        }
        
        AppConfig.log('📊 Baseline metadata loaded from history:');
        AppConfig.log('   - ID: $_baselineId');
        AppConfig.log('   - Confidence: $_baselineConfidence');
        AppConfig.log('   - Samples: $_baselineNumSamples');
        
        notifyListeners();
      }
    } catch (e) {
      AppConfig.logError('Could not fetch baseline history', e);
      // Silently fail - we'll use first prediction date as fallback
    }
  }

  // Get days since baseline for a given date
  int getDaysSinceBaseline(DateTime date) {
    if (_baselineDate == null) return 0;
    return date.difference(_baselineDate!).inDays;
  }

  // Get min and max deviation values for chart scaling
  double get minDeviation {
    if (_deviationPoints.isEmpty) return 0.0;
    return _deviationPoints.map((p) => p.deviation).reduce((a, b) => a < b ? a : b);
  }

  double get maxDeviation {
    if (_deviationPoints.isEmpty) return 1.0;
    return _deviationPoints.map((p) => p.deviation).reduce((a, b) => a > b ? a : b);
  }

  // Get average deviation
  double get averageDeviation {
    if (_deviationPoints.isEmpty) return 0.0;
    final sum = _deviationPoints.map((p) => p.deviation).reduce((a, b) => a + b);
    return sum / _deviationPoints.length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setErrorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  void clear() {
    _deviationPoints = [];
    _baselineDate = null;
    _errorMessage = null;
    _baselineId = null;
    _baselineConfidence = null;
    _baselineNumSamples = null;
    _baselineTractorHours = null;
    _baselineLoadCondition = null;
    notifyListeners();
  }
}

