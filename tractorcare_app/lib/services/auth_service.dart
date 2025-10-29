// lib/services/auth_service.dart

import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Initialize auth service
  Future<void> init() async {
    await _loadToken();
  }

  // Load saved token
  Future<void> _loadToken() async {
    final token = await _storage.getToken();
    if (token != null) {
      _api.setToken(token);
      try {
        await loadCurrentUser();
      } catch (e) {
        // Token might be expired
        await logout();
      }
    }
  }

  // Register new user
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final userData = {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
    };

    final response = await _api.register(userData);
    
    // Auto-login after registration
    return await login(email, password);
  }

  // Login user
  Future<User> login(String email, String password) async {
    final response = await _api.login(email, password);
    
    final token = response['access_token'];
    if (token == null) {
      throw Exception('No token received');
    }

    // Save token
    await _storage.saveToken(token);
    _api.setToken(token);

    // Load user data
    await loadCurrentUser();

    if (_currentUser == null) {
      throw Exception('Failed to load user data');
    }

    return _currentUser!;
  }

  // Load current user data
  Future<User> loadCurrentUser() async {
    final userData = await _api.getCurrentUser();
    _currentUser = User.fromJson(userData);
    
    // Save user data locally
    await _storage.saveUser(_currentUser!);
    
    return _currentUser!;
  }

  // Logout user
  Future<void> logout() async {
    _currentUser = null;
    _api.clearToken();
    await _storage.clearAll();
  }

  // Check if user is logged in
  Future<bool> checkAuth() async {
    final token = await _storage.getToken();
    if (token == null) return false;

    _api.setToken(token);
    
    try {
      await loadCurrentUser();
      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }

  // Update user profile
  Future<User> updateProfile(Map<String, dynamic> userData) async {
    // TODO: Implement update profile API endpoint
    throw UnimplementedError('Update profile not implemented yet');
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // TODO: Implement change password API endpoint
    throw UnimplementedError('Change password not implemented yet');
  }
}