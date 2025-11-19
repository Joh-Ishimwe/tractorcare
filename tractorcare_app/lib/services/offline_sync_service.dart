// lib/services/offline_sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import 'api_service.dart';
import '../models/tractor.dart';
import '../config/app_config.dart';

class OfflineSyncService extends ChangeNotifier {
  final StorageService _storage = StorageService();
  
  Timer? _connectivityTimer;
  bool _isSyncing = false;
  bool _isOnline = false;
  int _pendingChangesCount = 0;
  
  // Getters
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  int get pendingChangesCount => _pendingChangesCount;
  bool get hasInternetConnection => _isOnline;
  
  // Singleton pattern
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  // Initialize the service
  Future<void> initialize() async {
    AppConfig.log('🔄 OfflineSyncService initializing...');
    
    // Set initial state to offline until we verify connectivity
    _isOnline = false;
    
    // Do an immediate connectivity check
    await _checkConnectivity();
    await _updatePendingChangesCount();
    
    AppConfig.log('✅ OfflineSyncService initialized - Online: $_isOnline');
    
    // Check connectivity every 30 seconds (less frequent to reduce false positives)
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _checkConnectivity(),
    );
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  // Check current connectivity status by trying to reach the API
  Future<void> _checkConnectivity() async {
    bool wasOnline = _isOnline;
    
    try {
      // Use the /health endpoint which is designed for connectivity checks
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      // Health endpoint should return 200 if server is healthy
      if (response.statusCode == 200) {
        _isOnline = true;
        
        // Only log and notify if status changed
        if (!wasOnline) {
          AppConfig.log('✅ Online: API server reachable');
          notifyListeners();
          
          // If we just came online, attempt to sync
          if (_pendingChangesCount > 0) {
            syncPendingChanges();
          }
        }
      } else {
        // Non-200 response from health endpoint - treat as offline
        _isOnline = false;
        if (wasOnline) {
          AppConfig.log('❌ Offline: Health check returned ${response.statusCode}');
          notifyListeners();
        }
      }
    } catch (e) {
      // Network errors (timeout, connection refused, etc.) mean we're offline
      _isOnline = false;
      
      // Only log and notify if status changed
      if (wasOnline) {
        // Don't log timeout errors as they're common and not critical
        if (e.toString().contains('TimeoutException')) {
          AppConfig.log('⏱️ Connectivity check timeout (server may be slow)');
        } else {
          AppConfig.log('❌ Offline: Cannot reach API server - $e');
        }
        notifyListeners();
      }
    }
  }

  // Update pending changes count
  Future<void> _updatePendingChangesCount() async {
    final pendingItems = await _storage.getPendingSyncItems();
    _pendingChangesCount = pendingItems.length;
    notifyListeners();
  }

  // Manual refresh - useful after login or when user wants to check connectivity
  Future<void> refreshConnectivity() async {
    AppConfig.log('🔄 Manual connectivity refresh requested');
    await _checkConnectivity();
    await _updatePendingChangesCount();
  }

  // ==================== OFFLINE OPERATIONS ====================

  // Record maintenance offline
  Future<void> recordMaintenanceOffline({
    required String tractorId,
    required String taskName,
    required String description,
    required DateTime completionDate,
    required double completionHours,
    required int actualTimeMinutes,
    int? actualCostRwf,
    String? serviceLocation,
    String? serviceProvider,
    String? notes,
    String? performedBy,
    List<String>? partsUsed,
  }) async {
    final maintenanceRecord = {
      'type': 'maintenance_record',
      'tractor_id': tractorId,
      'task_name': taskName,
      'description': description,
      'completion_date': completionDate.toIso8601String(),
      'completion_hours': completionHours,
      'actual_time_minutes': actualTimeMinutes,
      'actual_cost_rwf': actualCostRwf,
      'service_location': serviceLocation,
      'service_provider': serviceProvider,
      'notes': notes,
      'performed_by': performedBy,
      'parts_used': partsUsed ?? [],
    };

    await _storage.addPendingSyncItem(maintenanceRecord);
    await _updatePendingChangesCount();

    // Also update local maintenance records cache
    await _updateLocalMaintenanceRecords(tractorId, maintenanceRecord);
  }

  // Log usage hours offline
  Future<void> logUsageOffline({
    required String tractorId,
    required double hoursOperated,
    required DateTime date,
    String? notes,
    String? operatorName,
    String? location,
  }) async {
    final usageLog = {
      'type': 'usage_log',
      'tractor_id': tractorId,
      'hours_operated': hoursOperated,
      'date': date.toIso8601String(),
      'notes': notes,
      'operator_name': operatorName,
      'location': location,
    };

    await _storage.addPendingSyncItem(usageLog);
    await _updatePendingChangesCount();

    // Also update local usage logs cache
    await _updateLocalUsageLogs(usageLog);
  }

  // Update tractor offline
  Future<void> updateTractorOffline({
    required String tractorId,
    Map<String, dynamic>? updates,
  }) async {
    if (updates == null || updates.isEmpty) return;

    final tractorUpdate = {
      'type': 'tractor_update',
      'tractor_id': tractorId,
      'updates': updates,
    };

    await _storage.addPendingSyncItem(tractorUpdate);
    await _updatePendingChangesCount();

    // Also update local tractors cache
    await _updateLocalTractor(tractorId, updates);
  }

  // ==================== LOCAL CACHE UPDATES ====================

  Future<void> _updateLocalMaintenanceRecords(String tractorId, Map<String, dynamic> newRecord) async {
    // For now, just store as raw data - we'll implement proper models later
    final records = await _storage.getUsageLogsOffline();
    records.add(newRecord);
    await _storage.saveUsageLogsOffline(records);
  }

  Future<void> _updateLocalUsageLogs(Map<String, dynamic> newLog) async {
    final logs = await _storage.getUsageLogsOffline();
    logs.add(newLog);
    await _storage.saveUsageLogsOffline(logs);
  }

  Future<void> _updateLocalTractor(String tractorId, Map<String, dynamic> updates) async {
    final tractors = await _storage.getTractorsOffline();
    final tractorIndex = tractors.indexWhere((t) => t.tractorId == tractorId);
    
    if (tractorIndex != -1) {
      // Update the tractor fields - create new tractor with updated values
      final tractor = tractors[tractorIndex];
      final updatedTractor = Tractor(
        id: tractor.id,
        userId: tractor.userId,
        tractorId: tractor.tractorId,
        model: updates['model'] ?? tractor.model,
        make: updates['make'] ?? tractor.make,
        purchaseDate: updates['purchase_date'] != null 
            ? DateTime.parse(updates['purchase_date']) 
            : tractor.purchaseDate,
        engineHours: updates['engine_hours']?.toDouble() ?? tractor.engineHours,
        usageIntensity: updates['usage_intensity'] ?? tractor.usageIntensity,
        createdAt: tractor.createdAt,
      );
      
      tractors[tractorIndex] = updatedTractor;
      await _storage.saveTractorsOffline(tractors);
    }
  }

  // ==================== SYNC OPERATIONS ====================

  // Sync all pending changes to server
  Future<bool> syncPendingChanges() async {
    if (!_isOnline || _isSyncing) {
      AppConfig.log('⏸️ Sync skipped: Online=$_isOnline, Syncing=$_isSyncing');
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final pendingItems = await _storage.getPendingSyncItems();
      AppConfig.log('🔄 Starting sync of ${pendingItems.length} pending items...');
      
      int syncedCount = 0;
      int failedCount = 0;
      
      for (final item in pendingItems) {
        try {
          AppConfig.log('📤 Syncing item: ${item['type']} (id: ${item['pending_sync_id'] ?? item['id']})');
          await _syncSingleItem(item);
          // Remove item using either pending_sync_id or id
          final itemId = item['pending_sync_id'] ?? item['id'];
          if (itemId != null) {
            await _storage.removePendingSyncItem(itemId);
            syncedCount++;
            AppConfig.log('✅ Successfully synced and removed item: $itemId');
          }
        } catch (e) {
          final itemId = item['pending_sync_id'] ?? item['id'] ?? 'unknown';
          AppConfig.logError('❌ Failed to sync item $itemId', e);
          failedCount++;
          // Continue with other items, don't stop the whole sync
        }
      }

      await _storage.updateLastSyncTimestamp();
      await _updatePendingChangesCount();
      
      AppConfig.log('✅ Sync completed: $syncedCount succeeded, $failedCount failed');
      return syncedCount > 0;
    } catch (e) {
      AppConfig.logError('Sync failed', e);
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Sync a single item (simplified version)
  Future<void> _syncSingleItem(Map<String, dynamic> item) async {
    final type = item['type'];
    final apiService = ApiService();
    
    switch (type) {
      case 'maintenance_record':
        try {
          AppConfig.log('🔧 Syncing maintenance record for tractor: ${item['tractor_id']}');
          await apiService.createMaintenance({
            'tractor_id': item['tractor_id'],
            'task_name': item['task_name'],
            'description': item['description'] ?? '',
            'completion_date': item['completion_date'],
            'completion_hours': item['completion_hours'] ?? 1,
            'actual_time_minutes': item['actual_time_minutes'] ?? 30,
            'actual_cost_rwf': item['actual_cost_rwf'] ?? 0,
            'service_location': item['service_location'] ?? '',
            'service_provider': item['service_provider'] ?? '',
            'notes': item['notes'] ?? '',
            'performed_by': item['performed_by'] ?? '',
            'parts_used': item['parts_used'] ?? [],
          });
          AppConfig.log('✅ Maintenance record synced successfully');
        } catch (e) {
          AppConfig.logError('❌ Failed to sync maintenance record', e);
          rethrow;
        }
        break;
        
      case 'maintenance_task':
        try {
          AppConfig.log('🔧 Syncing maintenance task for tractor: ${item['tractor_id']}');
          await apiService.createMaintenanceTask(item['task_data'] ?? {});
          AppConfig.log('✅ Maintenance task synced successfully');
        } catch (e) {
          AppConfig.logError('❌ Failed to sync maintenance task', e);
          rethrow;
        }
        break;
        
      case 'maintenance_update':
        try {
          AppConfig.log('🔧 Syncing maintenance update: ${item['maintenance_id']}');
          await apiService.updateMaintenanceRecord(item['maintenance_id'], item['updates'] ?? {});
          AppConfig.log('✅ Maintenance update synced successfully');
        } catch (e) {
          AppConfig.logError('❌ Failed to sync maintenance update', e);
          rethrow;
        }
        break;
        
      case 'usage_log':
        try {
          AppConfig.log('Syncing usage log for tractor: ${item['tractor_id']}');
          await apiService.addUsageLog(
            item['tractor_id'],
            Map<String, dynamic>.from(item['data']),
          );
          AppConfig.log('✅ Usage log synced successfully');
        } catch (e) {
          AppConfig.logError('Failed to sync usage log', e);
          rethrow;
        }
        break;
        
      case 'audio_upload':
        try {
          AppConfig.log('🎵 Syncing audio upload for tractor: ${item['tractor_id']}');
          final audioData = item['audio_data'];
          if (audioData == null || audioData.toString().isEmpty) {
            throw Exception('Audio data is missing or empty');
          }
          final audioBytes = base64Decode(audioData.toString());
          final prediction = await apiService.uploadAudioBytes(
            bytes: audioBytes,
            filename: item['filename'] ?? 'recording.wav',
            tractorId: item['tractor_id'],
            engineHours: (item['engine_hours'] ?? 0).toDouble(),
          );
          AppConfig.log('✅ Audio upload synced successfully - Prediction ID: ${prediction.id}');
        } catch (e) {
          AppConfig.logError('❌ Failed to sync audio upload', e);
          rethrow;
        }
        break;
        
      case 'tractor_update':
        // For now, just log that we would sync this
        AppConfig.log('Would sync tractor update: ${item['tractor_id']}');
        break;
        
      default:
        AppConfig.log('Unknown sync item type: $type');
    }
  }

  // Force sync data from server
  Future<void> forceSync() async {
    if (!_isOnline) return;

    try {
      // Fetch fresh data from server
      await refreshAllData();
      
      // Then sync pending changes
      await syncPendingChanges();
    } catch (e) {
      debugPrint('Force sync failed: $e');
    }
  }

  // Refresh all data from server (simplified)
  Future<void> refreshAllData() async {
    if (!_isOnline) return;

    try {
      // For now, just log that we would refresh data
      debugPrint('Would refresh all data from server');
      
      // TODO: Implement actual data fetching when API methods are available
      
    } catch (e) {
      debugPrint('Failed to refresh data: $e');
    }
  }

  // Get sync status info
  Map<String, dynamic> getSyncStatus() {
    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'pending_changes_count': _pendingChangesCount,
      'has_pending_changes': _pendingChangesCount > 0,
    };
  }

  // Manual method to mark as offline for testing
  void setOfflineMode(bool isOffline) {
    _isOnline = !isOffline;
    notifyListeners();
  }
}