// lib/providers/tractor_provider.dart

import 'package:flutter/material.dart';
import '../models/tractor.dart';
import '../models/audio_prediction.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/offline_sync_service.dart';

class TractorProvider with ChangeNotifier {
  final ApiService _api = ApiService(); // Now using singleton
  final StorageService _storage = StorageService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  List<Tractor> _tractors = [];
  Tractor? _selectedTractor;
  bool _isLoading = false;
  String? _error;
  
  // Store recent predictions for each tractor
  final Map<String, List<AudioPrediction>> _recentPredictions = {};

  List<Tractor> get tractors => _tractors;
  Tractor? get selectedTractor => _selectedTractor;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all tractors with offline support
  Future<void> fetchTractors() async {
    _setLoading(true);
    _clearError();

    try {
      if (_offlineSync.isOnline) {
        // Fetch from API and cache offline
        _tractors = await _api.getTractors();
        await _storage.saveTractorsOffline(_tractors);
      } else {
        // Load from offline storage
        _tractors = await _storage.getTractorsOffline();
        if (_tractors.isEmpty) {
          throw Exception('No offline data available. Please connect to internet.');
        }
      }
      _setLoading(false);
    } catch (e) {
      // Fallback to offline data if API fails
      try {
        _tractors = await _storage.getTractorsOffline();
        if (_tractors.isNotEmpty) {
          _setError('Showing offline data. ${e.toString()}');
        } else {
          _setError(e.toString());
        }
      } catch (offlineError) {
        _setError(e.toString());
      }
      _setLoading(false);
    }
  }

  // Get single tractor with offline support
  Future<void> getTractor(String tractorId) async {
    _setLoading(true);
    _clearError();

    try {
      if (_offlineSync.isOnline) {
        // Fetch from API
        _selectedTractor = await _api.getTractor(tractorId);
      } else {
        // Find in offline tractors
        final offlineTractors = await _storage.getTractorsOffline();
        _selectedTractor = offlineTractors.firstWhere(
          (tractor) => tractor.tractorId == tractorId,
          orElse: () => throw Exception('Tractor not found in offline data'),
        );
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Load recent predictions for all tractors to determine status
  Future<void> loadRecentPredictions() async {
    try {
      _recentPredictions.clear();
      
      for (final tractor in _tractors) {
        try {
          List<AudioPrediction> predictions;
          if (_offlineSync.isOnline) {
            // Get the most recent predictions from API and cache them
            predictions = await _api.getPredictions(tractor.tractorId);
            await _storage.savePredictionsOffline(predictions);
          } else {
            // Load from offline storage
            predictions = await _storage.getPredictionsOffline();
            predictions = predictions.where((p) => p.tractorId == tractor.tractorId).toList();
          }
          _recentPredictions[tractor.tractorId] = predictions;
        } catch (e) {
          // If we can't load predictions for a tractor, try offline data
          try {
            final offlinePredictions = await _storage.getPredictionsOffline();
            final tractorPredictions = offlinePredictions.where((p) => p.tractorId == tractor.tractorId).toList();
            _recentPredictions[tractor.tractorId] = tractorPredictions;
          } catch (offlineError) {
            print('Failed to load predictions for tractor ${tractor.tractorId}: $e');
            _recentPredictions[tractor.tractorId] = [];
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print('Failed to load recent predictions: $e');
    }
  }

  // Check if a tractor has recent abnormal predictions
  bool _hasCriticalPredictions(String tractorId) {
    final predictions = _recentPredictions[tractorId] ?? [];
    if (predictions.isEmpty) return false;
    
    // Check if the most recent prediction is abnormal
    final mostRecent = predictions.first;
    return mostRecent.predictionClass == PredictionClass.abnormal && 
           mostRecent.anomalyScore > 0.8; // High anomaly score = critical
  }

  // Check if a tractor has recent warning-level predictions  
  bool _hasWarningPredictions(String tractorId) {
    final predictions = _recentPredictions[tractorId] ?? [];
    if (predictions.isEmpty) return false;
    
    // Check if the most recent prediction shows warning signs
    final mostRecent = predictions.first;
    return mostRecent.predictionClass == PredictionClass.abnormal && 
           mostRecent.anomalyScore > 0.5 && mostRecent.anomalyScore <= 0.8; // Medium anomaly score = warning
  }

  // Add new prediction and update critical status in real-time
  void addNewPrediction(String tractorId, AudioPrediction prediction) {
    final currentPredictions = _recentPredictions[tractorId] ?? [];
    
    // Add new prediction at the beginning (most recent first)
    final updatedPredictions = [prediction, ...currentPredictions];
    
    // Keep only the last 10 predictions to avoid memory issues
    if (updatedPredictions.length > 10) {
      updatedPredictions.removeRange(10, updatedPredictions.length);
    }
    
    _recentPredictions[tractorId] = updatedPredictions;
    
    // Notify listeners to update the dashboard critical status immediately
    notifyListeners();
    
    debugPrint('🔔 Updated predictions for $tractorId: ${prediction.predictionClass} (${prediction.anomalyScore})');
  }

  // Create new tractor
  Future<bool> createTractor(Map<String, dynamic> tractorData) async {
    _setLoading(true);
    _clearError();

    try {
      final tractor = await _api.createTractor(tractorData);
      _tractors.insert(0, tractor);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle specific authentication errors
      if (errorMessage.contains('Authentication failed') || 
          errorMessage.contains('Not authenticated') ||
          errorMessage.contains('401')) {
        errorMessage = 'Please login again to continue';
      } else if (errorMessage.contains('403')) {
        errorMessage = 'You are not authorized to create tractors';
      }
      
      _setError(errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Update tractor
  Future<bool> updateTractor(
    String tractorId,
    Map<String, dynamic> tractorData,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedTractor = await _api.updateTractor(tractorId, tractorData);
      
      // Update in list (match by tractorId, which API uses)
      final index = _tractors.indexWhere((t) => t.tractorId == tractorId);
      if (index != -1) {
        _tractors[index] = updatedTractor;
      }
      
      // Update selected tractor if it's the same
      if (_selectedTractor?.tractorId == tractorId) {
        _selectedTractor = updatedTractor;
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Delete tractor
  Future<bool> deleteTractor(String tractorId) async {
    _setLoading(true);
    _clearError();

    try {
      await _api.deleteTractor(tractorId);
      
      // Remove from list
      _tractors.removeWhere((t) => t.tractorId == tractorId);
      
      // Clear selected tractor if it's the same
      if (_selectedTractor?.tractorId == tractorId) {
        _selectedTractor = null;
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Select tractor
  void selectTractor(Tractor tractor) {
    _selectedTractor = tractor;
    notifyListeners();
  }

  // Clear selected tractor
  void clearSelectedTractor() {
    _selectedTractor = null;
    notifyListeners();
  }

  // Get tractors by status
  List<Tractor> getTractorsByStatus(TractorStatus status) {
    return _tractors.where((t) => t.status == status).toList();
  }

  // Get critical tractors (based on recent abnormal predictions)
  List<Tractor> getCriticalTractors() {
    return _tractors.where((tractor) => _hasCriticalPredictions(tractor.tractorId)).toList();
  }

  // Get warning tractors (based on recent warning-level predictions)
  List<Tractor> getWarningTractors() {
    return _tractors.where((tractor) => _hasWarningPredictions(tractor.tractorId)).toList();
  }

  // Get the tractor with the most recent critical issue (for navigation)
  Tractor? getMostRecentCriticalTractor() {
    final criticalTractors = getCriticalTractors();
    if (criticalTractors.isEmpty) return null;
    
    // Find the tractor with the most recent abnormal prediction
    Tractor? mostRecentCritical;
    DateTime? latestAbnormalTime;
    
    for (final tractor in criticalTractors) {
      final predictions = _recentPredictions[tractor.tractorId] ?? [];
      if (predictions.isNotEmpty) {
        final mostRecentPrediction = predictions.first;
        if (mostRecentPrediction.predictionClass == PredictionClass.abnormal) {
          if (latestAbnormalTime == null || mostRecentPrediction.createdAt.isAfter(latestAbnormalTime)) {
            latestAbnormalTime = mostRecentPrediction.createdAt;
            mostRecentCritical = tractor;
          }
        }
      }
    }
    
    return mostRecentCritical;
  }

  // Get the tractor with the most recent warning issue (for navigation) 
  Tractor? getMostRecentWarningTractor() {
    final warningTractors = getWarningTractors();
    if (warningTractors.isEmpty) return null;
    
    // Find the tractor with the most recent warning prediction
    Tractor? mostRecentWarning;
    DateTime? latestWarningTime;
    
    for (final tractor in warningTractors) {
      final predictions = _recentPredictions[tractor.tractorId] ?? [];
      if (predictions.isNotEmpty) {
        final mostRecentPrediction = predictions.first;
        if (mostRecentPrediction.predictionClass == PredictionClass.abnormal) {
          if (latestWarningTime == null || mostRecentPrediction.createdAt.isAfter(latestWarningTime)) {
            latestWarningTime = mostRecentPrediction.createdAt;
            mostRecentWarning = tractor;
          }
        }
      }
    }
    
    return mostRecentWarning;
  }

  // Get good tractors
  List<Tractor> getGoodTractors() {
    return getTractorsByStatus(TractorStatus.good);
  }

  // Search tractors
  List<Tractor> searchTractors(String query) {
    if (query.isEmpty) return _tractors;
    
    final lowercaseQuery = query.toLowerCase();
    return _tractors.where((tractor) {
      return tractor.tractorId.toLowerCase().contains(lowercaseQuery) ||
          tractor.model.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Sort tractors
  void sortTractors(String sortBy) {
    switch (sortBy) {
      case 'id':
        _tractors.sort((a, b) => a.tractorId.compareTo(b.tractorId));
        break;
      case 'model':
        _tractors.sort((a, b) => a.model.compareTo(b.model));
        break;
      case 'hours':
        _tractors.sort((a, b) => b.engineHours.compareTo(a.engineHours));
        break;
      case 'status':
        _tractors.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }
    notifyListeners();
  }

  // ==================== OFFLINE EDITING ====================

  // Add usage log with offline support
  Future<void> addUsageLog(String tractorId, Map<String, dynamic> usageData) async {
    try {
      if (_offlineSync.isOnline) {
        // Online: Submit directly to API
        await _api.addUsageLog(tractorId, usageData);
      } else {
        // Offline: Store for later sync
        await _addPendingChange({
          'type': 'usage_log',
          'tractorId': tractorId,
          'data': usageData,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      // Update local tractor data if available
      if (_selectedTractor?.tractorId == tractorId) {
        // Update local usage stats
        _selectedTractor = _selectedTractor!.copyWith(
          engineHours: (_selectedTractor!.engineHours) + (usageData['hours'] as double? ?? 0),
        );
        notifyListeners();
      }
      
    } catch (e) {
      if (_offlineSync.isOnline) {
        // Failed online, save for offline sync
        await _addPendingChange({
          'type': 'usage_log',
          'tractorId': tractorId,
          'data': usageData,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      rethrow;
    }
  }

  // Update maintenance record with offline support
  Future<void> updateMaintenanceRecord(String tractorId, String maintenanceId, Map<String, dynamic> updates) async {
    try {
      if (_offlineSync.isOnline) {
        // Online: Update directly via API
        await _api.updateMaintenanceRecord(maintenanceId, updates);
      } else {
        // Offline: Store for later sync
        await _addPendingChange({
          'type': 'maintenance_update',
          'tractorId': tractorId,
          'maintenanceId': maintenanceId,
          'data': updates,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      notifyListeners();
      
    } catch (e) {
      if (_offlineSync.isOnline) {
        // Failed online, save for offline sync
        await _addPendingChange({
          'type': 'maintenance_update',
          'tractorId': tractorId,
          'maintenanceId': maintenanceId,
          'data': updates,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      rethrow;
    }
  }

  // Add maintenance record with offline support
  Future<void> addMaintenanceRecord(String tractorId, Map<String, dynamic> maintenanceData) async {
    try {
      if (_offlineSync.isOnline) {
        // Online: Submit directly to API
        await _api.addMaintenanceRecord(tractorId, maintenanceData);
      } else {
        // Offline: Store for later sync
        await _addPendingChange({
          'type': 'maintenance_add',
          'tractorId': tractorId,
          'data': maintenanceData,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      
      notifyListeners();
      
    } catch (e) {
      if (_offlineSync.isOnline) {
        // Failed online, save for offline sync
        await _addPendingChange({
          'type': 'maintenance_add',
          'tractorId': tractorId,
          'data': maintenanceData,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      rethrow;
    }
  }

  // Helper method to add pending changes
  Future<void> _addPendingChange(Map<String, dynamic> change) async {
    final pendingItems = await _storage.getPendingSyncItems();
    pendingItems.add(change);
    await _storage.savePendingSyncItems(pendingItems);
  }

  // Get offline edits for display
  Future<List<Map<String, dynamic>>> getPendingEdits() async {
    return await _storage.getPendingSyncItems();
  }

  // Clear specific pending edit (for manual resolution)
  Future<void> clearPendingEdit(int index) async {
    final pendingItems = await _storage.getPendingSyncItems();
    if (index < pendingItems.length) {
      pendingItems.removeAt(index);
      await _storage.savePendingSyncItems(pendingItems);
      notifyListeners();
    }
  }

  // Helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}