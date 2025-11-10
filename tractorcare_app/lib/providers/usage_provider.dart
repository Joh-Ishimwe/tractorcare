import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/offline_sync_service.dart';

class UsageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();

  List<dynamic> _usageHistory = [];
  Map<String, dynamic>? _usageStats;
  List<Map<String, dynamic>> _pendingUsageLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<dynamic> get usageHistory => _usageHistory;
  Map<String, dynamic>? get usageStats => _usageStats;
  List<Map<String, dynamic>> get pendingUsageLogs => _pendingUsageLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPendingLogs => _pendingUsageLogs.isNotEmpty;

  UsageProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPendingLogs();
    
    // Listen to connectivity changes by checking periodically
    // The OfflineSyncService doesn't have a stream, but we can use notifyListeners
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

  Future<void> syncPendingLogs() async {
    if (_pendingUsageLogs.isEmpty) return;

    final List<Map<String, dynamic>> failedLogs = [];
    
    for (final log in _pendingUsageLogs) {
      try {
        await _apiService.logDailyUsage(
          log['tractor_id'],
          log['total_hours'],
          log['notes'],
        );
        
        debugPrint('Successfully synced usage log for tractor: ${log['tractor_id']}');
      } catch (e) {
        debugPrint('Failed to sync usage log: $e');
        failedLogs.add(log);
      }
    }
    
    // Update pending logs with only failed ones
    _pendingUsageLogs = failedLogs;
    await _savePendingLogs();
    
    // Refresh usage history for all affected tractors
    final tractorIds = _pendingUsageLogs.map((log) => log['tractor_id']).toSet();
    for (final tractorId in tractorIds) {
      await fetchUsageHistory(tractorId, forceRefresh: true);
    }
    
    notifyListeners();
    
    if (_pendingUsageLogs.isEmpty) {
      debugPrint('All pending usage logs synced successfully');
    }
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
}