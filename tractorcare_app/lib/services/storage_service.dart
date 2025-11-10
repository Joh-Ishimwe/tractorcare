// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/tractor.dart';
import '../models/audio_prediction.dart';
import '../models/maintenance.dart';
import '../config/app_config.dart';

class StorageService {
  static const String _keyToken = AppConfig.tokenKey;
  static const String _keyUser = AppConfig.userKey;
  static const String _keyOnboarding = 'onboarding_complete';
  
  // Offline data keys
  static const String _keyTractors = 'offline_tractors';
  static const String _keyPredictions = 'offline_predictions';
  static const String _keyMaintenanceRecords = 'offline_maintenance_records';
  static const String _keyUsageLogs = 'offline_usage_logs';
  static const String _keyPendingSync = 'pending_sync_items';
  static const String _keyLastSync = 'last_sync_timestamp';

  // Get SharedPreferences instance
  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // ==================== TOKEN ====================

  Future<void> saveToken(String token) async {
    final prefs = await _prefs;
    await prefs.setString(_keyToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_keyToken);
  }

  Future<void> clearToken() async {
    final prefs = await _prefs;
    await prefs.remove(_keyToken);
  }

  // ==================== USER ====================

  Future<void> saveUser(User user) async {
    final prefs = await _prefs;
    final userJson = json.encode(user.toJson());
    await prefs.setString(_keyUser, userJson);
  }

  Future<User?> getUser() async {
    final prefs = await _prefs;
    final userJson = prefs.getString(_keyUser);
    
    if (userJson == null) return null;
    
    try {
      return User.fromJson(json.decode(userJson));
    } catch (e) {
      print('Error parsing user data: $e');
      return null;
    }
  }

  Future<void> clearUser() async {
    final prefs = await _prefs;
    await prefs.remove(_keyUser);
  }

  // ==================== ONBOARDING ====================

  Future<void> setOnboardingComplete() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyOnboarding, true);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyOnboarding) ?? false;
  }

  // ==================== GENERIC ====================

  Future<void> setString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _prefs;
    return prefs.getInt(key);
  }

  Future<void> setDouble(String key, double value) async {
    final prefs = await _prefs;
    await prefs.setDouble(key, value);
  }

  Future<double?> getDouble(String key) async {
    final prefs = await _prefs;
    return prefs.getDouble(key);
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }

  // ==================== CLEAR ALL ====================

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.clear();
  }

  // ==================== APP SETTINGS ====================

  Future<void> setThemeMode(String mode) async {
    await setString('theme_mode', mode);
  }

  Future<String?> getThemeMode() async {
    return await getString('theme_mode');
  }

  Future<void> setLanguage(String language) async {
    await setString('language', language);
  }

  Future<String?> getLanguage() async {
    return await getString('language');
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await setBool('notifications_enabled', enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    return await getBool('notifications_enabled') ?? true;
  }

  // ==================== CACHE ====================

  Future<void> setCachedData(String key, Map<String, dynamic> data) async {
    final prefs = await _prefs;
    final jsonString = json.encode(data);
    await prefs.setString('cache_$key', jsonString);
  }

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await _prefs;
    final jsonString = prefs.getString('cache_$key');
    
    if (jsonString == null) return null;
    
    try {
      return json.decode(jsonString);
    } catch (e) {
      print('Error parsing cached data: $e');
      return null;
    }
  }

  // ==================== OFFLINE DATA MANAGEMENT ====================

  // Tractors
  Future<void> saveTractorsOffline(List<Tractor> tractors) async {
    final prefs = await _prefs;
    final tractorsJson = tractors.map((t) => t.toJson()).toList();
    await prefs.setString(_keyTractors, json.encode(tractorsJson));
  }

  Future<List<Tractor>> getTractorsOffline() async {
    final prefs = await _prefs;
    final tractorsJson = prefs.getString(_keyTractors);
    
    if (tractorsJson == null) return [];
    
    try {
      final List<dynamic> tractorsList = json.decode(tractorsJson);
      return tractorsList.map((json) => Tractor.fromJson(json)).toList();
    } catch (e) {
      print('Error loading offline tractors: $e');
      return [];
    }
  }

  // Audio Predictions
  Future<void> savePredictionsOffline(List<AudioPrediction> predictions) async {
    final prefs = await _prefs;
    final predictionsJson = predictions.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPredictions, json.encode(predictionsJson));
  }

  Future<List<AudioPrediction>> getPredictionsOffline() async {
    final prefs = await _prefs;
    final predictionsJson = prefs.getString(_keyPredictions);
    
    if (predictionsJson == null) return [];
    
    try {
      final List<dynamic> predictionsList = json.decode(predictionsJson);
      return predictionsList.map((json) => AudioPrediction.fromJson(json)).toList();
    } catch (e) {
      print('Error loading offline predictions: $e');
      return [];
    }
  }

  // Maintenance Records
  Future<void> saveMaintenanceRecordsOffline(List<Maintenance> records) async {
    final prefs = await _prefs;
    final recordsJson = records.map((r) => r.toJson()).toList();
    await prefs.setString(_keyMaintenanceRecords, json.encode(recordsJson));
  }

  Future<List<Maintenance>> getMaintenanceRecordsOffline() async {
    final prefs = await _prefs;
    final recordsJson = prefs.getString(_keyMaintenanceRecords);
    
    if (recordsJson == null) return [];
    
    try {
      final List<dynamic> recordsList = json.decode(recordsJson);
      return recordsList.map((json) => Maintenance.fromJson(json)).toList();
    } catch (e) {
      print('Error loading offline maintenance records: $e');
      return [];
    }
  }

  // Usage Logs
  Future<void> saveUsageLogsOffline(List<Map<String, dynamic>> usageLogs) async {
    final prefs = await _prefs;
    await prefs.setString(_keyUsageLogs, json.encode(usageLogs));
  }

  Future<List<Map<String, dynamic>>> getUsageLogsOffline() async {
    final prefs = await _prefs;
    final logsJson = prefs.getString(_keyUsageLogs);
    
    if (logsJson == null) return [];
    
    try {
      final List<dynamic> logsList = json.decode(logsJson);
      return logsList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading offline usage logs: $e');
      return [];
    }
  }

  // ==================== PENDING SYNC MANAGEMENT ====================

  Future<void> addPendingSyncItem(Map<String, dynamic> item) async {
    final pendingItems = await getPendingSyncItems();
    
    // Add timestamp and unique ID
    item['pending_sync_id'] = DateTime.now().millisecondsSinceEpoch.toString();
    item['created_at'] = DateTime.now().toIso8601String();
    
    pendingItems.add(item);
    
    final prefs = await _prefs;
    await prefs.setString(_keyPendingSync, json.encode(pendingItems));
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final prefs = await _prefs;
    final pendingJson = prefs.getString(_keyPendingSync);
    
    if (pendingJson == null) return [];
    
    try {
      final List<dynamic> pendingList = json.decode(pendingJson);
      return pendingList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading pending sync items: $e');
      return [];
    }
  }

  Future<void> savePendingSyncItems(List<Map<String, dynamic>> items) async {
    final prefs = await _prefs;
    await prefs.setString(_keyPendingSync, json.encode(items));
  }

  Future<void> removePendingSyncItem(String syncId) async {
    final pendingItems = await getPendingSyncItems();
    pendingItems.removeWhere((item) => 
      item['pending_sync_id'] == syncId || item['id'] == syncId);
    
    final prefs = await _prefs;
    await prefs.setString(_keyPendingSync, json.encode(pendingItems));
  }

  Future<void> clearPendingSyncItems() async {
    final prefs = await _prefs;
    await prefs.remove(_keyPendingSync);
  }

  // ==================== SYNC TIMESTAMP ====================

  Future<void> updateLastSyncTimestamp() async {
    final prefs = await _prefs;
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await _prefs;
    final timestampStr = prefs.getString(_keyLastSync);
    
    if (timestampStr == null) return null;
    
    try {
      return DateTime.parse(timestampStr);
    } catch (e) {
      print('Error parsing last sync timestamp: $e');
      return null;
    }
  }

  // ==================== OFFLINE STATUS ====================

  Future<void> setOfflineMode(bool isOffline) async {
    await setBool('offline_mode', isOffline);
  }

  Future<bool> isOfflineMode() async {
    return await getBool('offline_mode') ?? false;
  }

  Future<bool> hasPendingChanges() async {
    final pendingItems = await getPendingSyncItems();
    return pendingItems.isNotEmpty;
  }

  Future<void> clearCache() async {
    final prefs = await _prefs;
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith('cache_')) {
        await prefs.remove(key);
      }
    }
  }
}