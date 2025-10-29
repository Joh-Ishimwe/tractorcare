// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'current_user';
  static const String _keyOnboarding = 'onboarding_complete';

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