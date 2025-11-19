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

  // Try to fetch baseline date (non-blocking, won't throw)
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

      final baselineStatusStr = baselineStatus['baseline_status']?.toString().toLowerCase();
      
      if (baselineStatusStr == 'completed' || baselineStatusStr == 'active') {
        // Try to get baseline creation date
        final baselineCreatedAt = baselineStatus['created_at'] ?? baselineStatus['finalized_at'];
        if (baselineCreatedAt != null) {
          _baselineDate = DateTime.parse(baselineCreatedAt.toString());
          notifyListeners();
          return;
        }
      }
      
      // If no date in status, try baseline history
      await _tryFetchBaselineFromHistory(tractorId);
    } catch (e) {
      AppConfig.logError('Could not fetch baseline status', e);
      // Try history as fallback
      await _tryFetchBaselineFromHistory(tractorId);
    }
  }

  // Try to fetch baseline date from history (non-blocking, won't throw)
  Future<void> _tryFetchBaselineFromHistory(String tractorId) async {
    try {
      final baselineHistory = await _apiService.getBaselineHistory(tractorId).timeout(
        const Duration(seconds: 10),
        onTimeout: () => <String, dynamic>{},
      );
      
      if (baselineHistory.isEmpty) return;

      // Check if there's a baseline in history
      if (baselineHistory['history'] != null && (baselineHistory['history'] as List).isNotEmpty) {
        // Get the most recent active baseline
        final history = baselineHistory['history'] as List;
        final activeBaseline = history.firstWhere(
          (b) => b['status'] == 'active' || b['status'] == 'completed',
          orElse: () => history.first,
        );
        final createdAt = activeBaseline['created_at'] ?? activeBaseline['finalized_at'];
        if (createdAt != null) {
          _baselineDate = DateTime.parse(createdAt.toString());
          notifyListeners();
        }
      } else if (baselineHistory['baseline'] != null) {
        // Fallback to direct baseline object
        final baseline = baselineHistory['baseline'];
        final createdAt = baseline['created_at'] ?? baseline['finalized_at'];
        if (createdAt != null) {
          _baselineDate = DateTime.parse(createdAt.toString());
          notifyListeners();
        }
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
    notifyListeners();
  }
}

