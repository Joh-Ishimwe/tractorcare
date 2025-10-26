// lib/services/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  User? _currentUser;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  // Initialize from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        try {
          _currentUser = await _apiService.getCurrentUser(_token!);
          _isAuthenticated = true;
        } catch (e) {
          await logout();
        }
      }
    } catch (e) {
      // print('Error initializing auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register
  Future<void> register(User user, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Backend returns the created user (no token). Perform a follow-up login.
      await _apiService.register(user, password);

      // Immediately login to fetch token and profile
      await login(user.email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      _token = response['access_token'];

      // Mark authenticated and save token early so subsequent profile calls use it.
      _isAuthenticated = true;
      await _saveAuthState();

      // Try to load current user profile but don't fail the login if profile fetch fails
      try {
        _currentUser = await _apiService.getCurrentUser(_token!);
      } catch (e) {
        // Profile fetch failed (e.g., backend returns placeholder). Continue without blocking login.
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _isAuthenticated = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('current_user');

    notifyListeners();
  }

  // Save auth state
  Future<void> _saveAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString('auth_token', _token!);
      }
    } catch (e) {
      // print('Error saving auth state: $e');
    }
  }
}
