import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/offline_sync_service.dart';
import 'maintenance_provider.dart';

class UsageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  MaintenanceProvider? _maintenanceProvider;

  List<dynamic> _usageHistory = [];
  Map<String, dynamic>? _usageStats;
  List<Map<String, dynamic>> _pendingUsageLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Deviation time-series data
  List<Map<String, dynamic>> _deviationTimeSeries = [];
  bool _deviationLoading = false;
  String? _deviationError;

  // Getters
  List<dynamic> get usageHistory => _usageHistory;
  Map<String, dynamic>? get usageStats => _usageStats;
  List<Map<String, dynamic>> get pendingUsageLogs => _pendingUsageLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingLogs => _pendingUsageLogs.isNotEmpty;
  List<Map<String, dynamic>> get deviationTimeSeries => _deviationTimeSeries;
  bool get deviationLoading => _deviationLoading;
  String? get deviationError => _deviationError;

  UsageProvider() {
    _initialize();
  }

  // Set the maintenance provider for creating tasks
  void setMaintenanceProvider(MaintenanceProvider maintenanceProvider) {
    _maintenanceProvider = maintenanceProvider;
  }

  Future<void> _initialize() async {
    await _loadPendingLogs();
    // Listen to OfflineSyncService for connectivity changes
    _offlineSyncService.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    // Schedule for next frame to avoid setState during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 UsageProvider: Connectivity changed - Online: ${_offlineSyncService.isOnline}, Pending logs: ${_pendingUsageLogs.length}');
      // When we come online and have pending logs, sync them
      if (_offlineSyncService.isOnline && _pendingUsageLogs.isNotEmpty) {
        debugPrint('📶 Connection restored, syncing ${_pendingUsageLogs.length} pending usage logs...');
        syncPendingLogs();
      } else if (!_offlineSyncService.isOnline) {
        debugPrint('📶 Lost connection');
      } else if (_pendingUsageLogs.isEmpty) {
        debugPrint('📶 Online but no pending logs to sync');
      }
    });
  }

  // Fetch deviation time-series for a tractor
  Future<void> fetchDeviationTimeSeries(String tractorId) async {
    _deviationLoading = true;
    _deviationError = null;
    notifyListeners();
    try {
      final data = await _apiService.fetchDeviationTimeSeries(tractorId);
      _deviationTimeSeries = data;
    } catch (e) {
      _deviationError = e.toString();
      _deviationTimeSeries = [];
    }
    _deviationLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _offlineSyncService.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> fetchUsageHistory(String tractorId, {bool forceRefresh = false}) async {
    try {
      _setLoading(true);
      _setErrorMessage(null);

      if (_offlineSyncService.isOnline || forceRefresh) {
        // Try to fetch from API
        try {
          final historyResponse = await _apiService.getUsageHistory(tractorId);
          final statsResponse = await _apiService.getUsageStats(tractorId);
          
          _usageHistory = historyResponse;
          _usageStats = statsResponse;
          
          // Cache the data
          await _storageService.setString('usage_history_$tractorId', jsonEncode(_usageHistory));
          await _storageService.setString('usage_stats_$tractorId', jsonEncode(_usageStats));
          
          // Check for usage-based maintenance tasks after successful data fetch
          if (_usageStats != null && _usageStats!['total_hours'] != null) {
            final currentHours = double.tryParse(_usageStats!['total_hours'].toString()) ?? 0.0;
            await _checkAndCreateUsageBasedTasks(tractorId, currentHours);
          }
          
          notifyListeners();
        } catch (e) {
          debugPrint('Error fetching usage data from API: $e');
          await _loadCachedData(tractorId);
          _setErrorMessage('Using cached data (offline)');
        }
      } else {
        // Load from cache when offline
        await _loadCachedData(tractorId);
        _setErrorMessage('Offline - showing cached data');
      }
    } catch (e) {
      debugPrint('Error in fetchUsageHistory: $e');
      _setErrorMessage('Failed to load usage data');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadCachedData(String tractorId) async {
    try {
      final cachedHistory = await _storageService.getString('usage_history_$tractorId');
      final cachedStats = await _storageService.getString('usage_stats_$tractorId');
      
      if (cachedHistory != null) {
        _usageHistory = jsonDecode(cachedHistory);
      }
      
      if (cachedStats != null) {
        _usageStats = jsonDecode(cachedStats);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached usage data: $e');
    }
  }

  Future<bool> logDailyUsage(String tractorId, double totalHours, String? notes) async {
    try {
      final usageLog = {
        'tractor_id': tractorId,
        'total_hours': totalHours,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (_offlineSyncService.isOnline) {
        // Try to submit immediately
        try {
          await _apiService.logDailyUsage(tractorId, totalHours, notes);
          
          // Check if maintenance tasks should be created based on engine hours
          await _checkAndCreateUsageBasedTasks(tractorId, totalHours);
          
          // Refresh data after successful submission
          await fetchUsageHistory(tractorId, forceRefresh: true);
          return true;
        } catch (e) {
          debugPrint('Failed to submit usage log immediately: $e');
          // Fall back to offline queuing
          await _queueUsageLog(usageLog);
          return true;
        }
      } else {
        // Queue for later submission
        await _queueUsageLog(usageLog);
        return true;
      }
    } catch (e) {
      debugPrint('Error in logDailyUsage: $e');
      _setErrorMessage('Failed to log usage');
      return false;
    }
  }

  Future<void> _queueUsageLog(Map<String, dynamic> usageLog) async {
    _pendingUsageLogs.add(usageLog);
    await _savePendingLogs();
    
    // Add to local history for immediate display
    final localUsageItem = {
      'date': usageLog['timestamp'],
      'hours_used': 0.0, // Will be calculated when synced
      'start_hours': 0.0, // Will be updated when synced
      'end_hours': usageLog['total_hours'],
      'notes': usageLog['notes'],
      'isPending': true,
    };
    
    _usageHistory.insert(0, localUsageItem);
    notifyListeners();
    
    debugPrint('Usage log queued for sync: ${usageLog['tractor_id']}');
  }

  Future<void> _loadPendingLogs() async {
    try {
      final pendingData = await _storageService.getString('pending_usage_logs');
      if (pendingData != null) {
        final List<dynamic> decoded = jsonDecode(pendingData);
        _pendingUsageLogs = decoded.cast<Map<String, dynamic>>();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading pending usage logs: $e');
    }
  }

  Future<void> _savePendingLogs() async {
    try {
      await _storageService.setString('pending_usage_logs', jsonEncode(_pendingUsageLogs));
    } catch (e) {
      debugPrint('Error saving pending usage logs: $e');
    }
  }

  // Manual sync method that can be called from UI
  Future<bool> manualSync() async {
    if (_pendingUsageLogs.isEmpty) {
      debugPrint('🔄 Manual sync: No pending logs to sync');
      return true;
    }

    if (!_offlineSyncService.isOnline) {
      debugPrint('❌ Manual sync: Device is offline');
      return false;
    }

    debugPrint('🔄 Manual sync started for ${_pendingUsageLogs.length} pending logs');
    
    final initialPendingCount = _pendingUsageLogs.length;
    await syncPendingLogs();
    
    final remainingPendingCount = _pendingUsageLogs.length;
    final successfulSyncs = initialPendingCount - remainingPendingCount;
    
    debugPrint('✅ Manual sync completed: $successfulSyncs synced, $remainingPendingCount failed');
    
    return remainingPendingCount == 0;
  }

  Future<void> syncPendingLogs() async {
    if (_pendingUsageLogs.isEmpty) {
      debugPrint('🔄 UsageProvider: No pending logs to sync');
      return;
    }

    debugPrint('🔄 UsageProvider: Starting sync of ${_pendingUsageLogs.length} pending logs...');
    
    final List<Map<String, dynamic>> failedLogs = [];
    
    for (final log in _pendingUsageLogs) {
      try {
        debugPrint('🔄 Syncing usage log for tractor: ${log['tractor_id']}');
        
        await _apiService.logDailyUsage(
          log['tractor_id'],
          log['total_hours'],
          log['notes'],
        );
        
        debugPrint('✅ Successfully synced usage log for tractor: ${log['tractor_id']}');
      } catch (e) {
        debugPrint('❌ Failed to sync usage log for tractor ${log['tractor_id']}: $e');
        failedLogs.add(log);
      }
    }
    
    // Update pending logs with only failed ones
    _pendingUsageLogs = failedLogs;
    await _savePendingLogs();
    
    if (_pendingUsageLogs.isEmpty) {
      debugPrint('✅ All pending usage logs synced successfully');
    } else {
      debugPrint('❌ ${_pendingUsageLogs.length} logs failed to sync');
    }
    
    // Refresh usage history for all affected tractors
    final tractorIds = _pendingUsageLogs.map((log) => log['tractor_id']).toSet();
    for (final tractorId in tractorIds) {
      await fetchUsageHistory(tractorId, forceRefresh: true);
    }
    
    notifyListeners();
  }

  Future<void> clearPendingLogs() async {
    _pendingUsageLogs.clear();
    await _storageService.remove('pending_usage_logs');
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Check if maintenance tasks should be created based on engine hours
  Future<void> _checkAndCreateUsageBasedTasks(String tractorId, double currentHours) async {
    try {
      debugPrint('🔍 Checking if maintenance tasks needed for tractor $tractorId at $currentHours hours');
      
      // Define maintenance intervals based on manufacturer recommendations (simplified)
      final maintenanceIntervals = {
        'oil_change': 100.0,      // Every 100 hours
        'filter_replacement': 200.0, // Every 200 hours  
        'inspection': 300.0,      // Every 300 hours
        'service': 500.0,         // Every 500 hours
      };

      // Get last maintenance hours from storage to avoid duplicate tasks
      final lastMaintenanceData = await _storageService.getString('last_maintenance_hours_$tractorId');
      Map<String, double> lastMaintenanceHours = {};
      
      if (lastMaintenanceData != null) {
        final decoded = jsonDecode(lastMaintenanceData);
        lastMaintenanceHours = Map<String, double>.from(decoded);
      }

      // Check each maintenance type
      for (final entry in maintenanceIntervals.entries) {
        final taskType = entry.key;
        final interval = entry.value;
        final lastHours = lastMaintenanceHours[taskType] ?? 0.0;
        
        // Calculate next due hours
        final nextDueHours = ((lastHours ~/ interval) + 1) * interval;
        
        debugPrint('📊 $taskType: Last at ${lastHours}h, Next due at ${nextDueHours}h, Current: ${currentHours}h');
        
        // If current hours exceed the next due hours, create a task
        if (currentHours >= nextDueHours) {
          debugPrint('⚠️ Creating maintenance task: $taskType due at ${nextDueHours}h');
          
          // Import is causing issues, so we'll use a simpler approach without direct import
          // Since this is called from usage logging, we'll store a flag for the UI to pick up
          await _scheduleMaintenanceTask(tractorId, taskType, nextDueHours);
          
          // Update last maintenance hours to avoid duplicates
          lastMaintenanceHours[taskType] = currentHours;
        }
      }
      
      // Save updated last maintenance hours
      await _storageService.setString('last_maintenance_hours_$tractorId', 
          jsonEncode(lastMaintenanceHours));
          
    } catch (e) {
      debugPrint('❌ Error checking usage-based maintenance: $e');
    }
  }

  Future<void> _scheduleMaintenanceTask(String tractorId, String taskType, double dueAtHours) async {
    try {
      // Create maintenance task directly through MaintenanceProvider if available
      if (_maintenanceProvider != null) {
        final currentHoursKey = 'current_hours_$tractorId';
        final currentHoursStr = await _storageService.getString(currentHoursKey);
        final currentHours = double.tryParse(currentHoursStr ?? '0') ?? 0.0;

        final success = await _maintenanceProvider!.createUsageBasedTask(
          tractorId, 
          taskType, 
          currentHours, 
          dueAtHours
        );
        
        if (success) {
          // Update last maintenance hours to prevent duplicate tasks
          await _storageService.setString(
            'last_${taskType}_hours_$tractorId',
            dueAtHours.toString()
          );
          debugPrint('✅ Created usage-based maintenance task: $taskType for tractor $tractorId');
          return;
        }
      }

      // Fallback: Store pending maintenance task locally if MaintenanceProvider unavailable
      final pendingTaskKey = 'pending_maintenance_$tractorId';
      final existingTasks = await _storageService.getString(pendingTaskKey);
      List<Map<String, dynamic>> tasks = [];
      
      if (existingTasks != null) {
        final decoded = jsonDecode(existingTasks);
        tasks = List<Map<String, dynamic>>.from(decoded);
      }
      
      // Add new task if not already present
      final taskExists = tasks.any((task) => 
          task['type'] == taskType && task['due_at_hours'] == dueAtHours);
          
      if (!taskExists) {
        tasks.add({
          'tractor_id': tractorId,
          'type': taskType,
          'due_at_hours': dueAtHours,
          'created_at': DateTime.now().toIso8601String(),
          'trigger_type': 'USAGE_INTERVAL',
          'title': _getTaskTitle(taskType),
          'description': _getTaskDescription(taskType, dueAtHours),
          'priority': _getTaskPriority(taskType),
        });
        
        await _storageService.setString(pendingTaskKey, jsonEncode(tasks));
        debugPrint('📝 Scheduled maintenance task: $taskType for tractor $tractorId');
      }
    } catch (e) {
      debugPrint('❌ Error scheduling maintenance task: $e');
    }
  }

  String _getTaskTitle(String taskType) {
    switch (taskType) {
      case 'oil_change':
        return 'Engine Oil Change';
      case 'filter_replacement':
        return 'Filter Replacement';
      case 'inspection':
        return 'Regular Inspection';
      case 'service':
        return 'Full Service';
      default:
        return 'Maintenance Task';
    }
  }

  String _getTaskDescription(String taskType, double dueAtHours) {
    switch (taskType) {
      case 'oil_change':
        return 'Change engine oil and oil filter. Due at ${dueAtHours.toStringAsFixed(1)} hours.';
      case 'filter_replacement':
        return 'Replace air and fuel filters. Due at ${dueAtHours.toStringAsFixed(1)} hours.';
      case 'inspection':
        return 'Perform regular inspection and maintenance checks. Due at ${dueAtHours.toStringAsFixed(1)} hours.';
      case 'service':
        return 'Complete full service including all systems check. Due at ${dueAtHours.toStringAsFixed(1)} hours.';
      default:
        return 'Scheduled maintenance task due at ${dueAtHours.toStringAsFixed(1)} hours.';
    }
  }

  String _getTaskPriority(String taskType) {
    switch (taskType) {
      case 'oil_change':
        return 'HIGH';
      case 'filter_replacement':
        return 'MEDIUM';
      case 'inspection':
        return 'MEDIUM';
      case 'service':
        return 'HIGH';
      default:
        return 'MEDIUM';
    }
  }
}