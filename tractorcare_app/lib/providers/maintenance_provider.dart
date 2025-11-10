import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/offline_sync_service.dart';
import '../models/maintenance.dart';
import '../models/audio_prediction.dart';

class MaintenanceProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  final List<Maintenance> _maintenanceTasks = [];
  List<Map<String, dynamic>> _pendingTasks = [];
  final bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Maintenance> get maintenanceTasks => _maintenanceTasks;
  List<Map<String, dynamic>> get pendingTasks => _pendingTasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingTasks => _pendingTasks.isNotEmpty;

  MaintenanceProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPendingTasks();
    
    // Listen to connectivity changes to sync pending tasks
    _offlineSyncService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    // Schedule the sync for the next frame to avoid setState during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 MaintenanceProvider: Connectivity changed - Online: ${_offlineSyncService.isOnline}, Pending tasks: ${_pendingTasks.length}');
      
      if (_offlineSyncService.isOnline && _pendingTasks.isNotEmpty) {
        debugPrint('📶 Connection restored, syncing ${_pendingTasks.length} pending maintenance tasks...');
        syncPendingTasks();
      }
    });
  }

  @override
  void dispose() {
    _offlineSyncService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  // Create maintenance task automatically when abnormal sound is detected
  Future<bool> createAbnormalSoundTask(String tractorId, AudioPrediction prediction) async {
    debugPrint('🚨 Creating maintenance task for abnormal sound detection - Tractor: $tractorId');
    
    final taskData = {
      'tractor_id': tractorId,
      'type': 'inspection',
      'task_name': 'Sound Analysis Inspection',
      'description': 'Inspection required due to abnormal sound detection. Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
      'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(), // Due tomorrow
      'priority': 'HIGH',
      'trigger_type': 'ABNORMAL_SOUND',
      'prediction_id': prediction.id,
      'notes': 'Automatically generated task due to abnormal sound pattern detected during audio analysis.',
      'estimated_time_minutes': 30,
      'estimated_cost': 0, // Inspection usually free
    };

    return await _createMaintenanceTask(taskData);
  }

  // Create maintenance task based on usage intervals
  Future<bool> createUsageBasedTask(String tractorId, String taskType, double currentHours, double dueAtHours) async {
    debugPrint('⏰ Creating usage-based maintenance task - Tractor: $tractorId, Type: $taskType');
    
    final taskData = {
      'tractor_id': tractorId,
      'type': taskType,
      'task_name': _getTaskNameForType(taskType),
      'description': _getTaskDescriptionForType(taskType),
      'due_at_hours': dueAtHours,
      'priority': 'MEDIUM',
      'trigger_type': 'USAGE_INTERVAL',
      'notes': 'Automatically generated task based on engine hours usage.',
      'estimated_time_minutes': _getEstimatedTimeForType(taskType),
      'estimated_cost': _getEstimatedCostForType(taskType),
    };

    return await _createMaintenanceTask(taskData);
  }

  // Create maintenance task manually
  Future<bool> createManualTask(Map<String, dynamic> taskData) async {
    taskData['trigger_type'] = 'MANUAL';
    return await _createMaintenanceTask(taskData);
  }

  Future<bool> _createMaintenanceTask(Map<String, dynamic> taskData) async {
    try {
      if (_offlineSyncService.isOnline) {
        // Online: Direct creation
        final maintenance = await _apiService.createMaintenanceTask(taskData);
        
        // Add to local list
        _maintenanceTasks.insert(0, maintenance);
        notifyListeners();
        
        debugPrint('✅ Maintenance task created successfully: ${maintenance.customType ?? maintenance.type.toString()}');
        return true;
      } else {
        // Offline: Queue for later sync
        await _queueTaskForSync(taskData);
        debugPrint('📱 Offline: Maintenance task queued for sync');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Failed to create maintenance task: $e');
      
      // If online creation failed, queue it
      if (_offlineSyncService.isOnline) {
        await _queueTaskForSync(taskData);
        debugPrint('🔄 Queued failed task for retry');
      }
      
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _queueTaskForSync(Map<String, dynamic> taskData) async {
    // Add timestamp and pending ID
    taskData['pending_id'] = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    taskData['created_at'] = DateTime.now().toIso8601String();
    taskData['status'] = 'PENDING';

    _pendingTasks.insert(0, taskData);
    await _savePendingTasks();
    notifyListeners();
  }

  Future<void> syncPendingTasks() async {
    if (_pendingTasks.isEmpty) {
      debugPrint('🔄 MaintenanceProvider: No pending tasks to sync');
      return;
    }

    debugPrint('🔄 MaintenanceProvider: Starting sync of ${_pendingTasks.length} pending tasks...');
    
    final List<Map<String, dynamic>> failedTasks = [];
    
    for (final taskData in _pendingTasks) {
      try {
        debugPrint('🔄 Syncing maintenance task: ${taskData['task_name']}');
        
        // Remove pending-specific fields before sending to API
        final cleanTaskData = Map<String, dynamic>.from(taskData);
        cleanTaskData.remove('pending_id');
        cleanTaskData.remove('created_at');
        cleanTaskData.remove('status');
        
        final maintenance = await _apiService.createMaintenanceTask(cleanTaskData);
        
        // Add to local list
        _maintenanceTasks.insert(0, maintenance);
        
        debugPrint('✅ Successfully synced maintenance task: ${maintenance.customType ?? maintenance.type.toString()}');
      } catch (e) {
        debugPrint('❌ Failed to sync maintenance task ${taskData['task_name']}: $e');
        failedTasks.add(taskData);
      }
    }
    
    // Update pending tasks with only failed ones
    _pendingTasks = failedTasks;
    await _savePendingTasks();
    
    if (_pendingTasks.isEmpty) {
      debugPrint('✅ All pending maintenance tasks synced successfully');
    } else {
      debugPrint('❌ ${_pendingTasks.length} tasks failed to sync');
    }
    
    notifyListeners();
  }

  Future<void> _loadPendingTasks() async {
    try {
      final pendingData = await _storageService.getString('pending_maintenance_tasks');
      if (pendingData != null) {
        final List<dynamic> decoded = jsonDecode(pendingData);
        _pendingTasks = decoded.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading pending maintenance tasks: $e');
    }
  }

  Future<void> _savePendingTasks() async {
    try {
      await _storageService.setString('pending_maintenance_tasks', jsonEncode(_pendingTasks));
    } catch (e) {
      debugPrint('Error saving pending maintenance tasks: $e');
    }
  }

  // Helper methods for task types
  String _getTaskNameForType(String type) {
    switch (type.toLowerCase()) {
      case 'oil_change':
        return 'Engine Oil Change';
      case 'filter_change':
        return 'Filter Replacement';
      case 'inspection':
        return 'General Inspection';
      case 'transmission_service':
        return 'Transmission Service';
      case 'hydraulic_service':
        return 'Hydraulic System Service';
      default:
        return 'Maintenance Task';
    }
  }

  String _getTaskDescriptionForType(String type) {
    switch (type.toLowerCase()) {
      case 'oil_change':
        return 'Regular engine oil and filter change to maintain engine performance';
      case 'filter_change':
        return 'Replace air, fuel, and hydraulic filters as per schedule';
      case 'inspection':
        return 'Comprehensive inspection of tractor systems and components';
      case 'transmission_service':
        return 'Transmission fluid change and system inspection';
      case 'hydraulic_service':
        return 'Hydraulic fluid change and system maintenance';
      default:
        return 'Scheduled maintenance task';
    }
  }

  int _getEstimatedTimeForType(String type) {
    switch (type.toLowerCase()) {
      case 'oil_change':
        return 45;
      case 'filter_change':
        return 30;
      case 'inspection':
        return 60;
      case 'transmission_service':
        return 90;
      case 'hydraulic_service':
        return 120;
      default:
        return 60;
    }
  }

  double _getEstimatedCostForType(String type) {
    switch (type.toLowerCase()) {
      case 'oil_change':
        return 25000; // RWF
      case 'filter_change':
        return 15000;
      case 'inspection':
        return 0; // Usually free
      case 'transmission_service':
        return 35000;
      case 'hydraulic_service':
        return 45000;
      default:
        return 20000;
    }
  }

  // Manual sync method that can be called from UI
  Future<bool> manualSync() async {
    if (_pendingTasks.isEmpty) {
      debugPrint('🔄 Manual sync: No pending tasks to sync');
      return true;
    }

    if (!_offlineSyncService.isOnline) {
      debugPrint('❌ Manual sync: Device is offline');
      return false;
    }

    debugPrint('🔄 Manual sync started for ${_pendingTasks.length} pending tasks');
    
    final initialPendingCount = _pendingTasks.length;
    await syncPendingTasks();
    
    final remainingPendingCount = _pendingTasks.length;
    final successfulSyncs = initialPendingCount - remainingPendingCount;
    
    debugPrint('✅ Manual sync completed: $successfulSyncs synced, $remainingPendingCount failed');
    
    return remainingPendingCount == 0;
  }

  Future<void> clearPendingTasks() async {
    _pendingTasks.clear();
    await _savePendingTasks();
    notifyListeners();
  }
}