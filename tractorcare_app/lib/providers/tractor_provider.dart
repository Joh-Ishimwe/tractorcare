// lib/providers/tractor_provider.dart

import 'package:flutter/material.dart';
import '../models/tractor.dart';
import '../services/api_service.dart';

class TractorProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Tractor> _tractors = [];
  Tractor? _selectedTractor;
  bool _isLoading = false;
  String? _error;

  List<Tractor> get tractors => _tractors;
  Tractor? get selectedTractor => _selectedTractor;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Fetch all tractors
  Future<void> fetchTractors() async {
    _setLoading(true);
    _clearError();

    try {
      _tractors = await _api.getTractors();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Get single tractor
  Future<void> getTractor(String tractorId) async {
    _setLoading(true);
    _clearError();

    try {
      _selectedTractor = await _api.getTractor(tractorId);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
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
      _setError(e.toString());
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
      
      // Update in list
      final index = _tractors.indexWhere((t) => t.id == tractorId);
      if (index != -1) {
        _tractors[index] = updatedTractor;
      }
      
      // Update selected tractor if it's the same
      if (_selectedTractor?.id == tractorId) {
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
      _tractors.removeWhere((t) => t.id == tractorId);
      
      // Clear selected tractor if it's the same
      if (_selectedTractor?.id == tractorId) {
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

  // Get critical tractors
  List<Tractor> getCriticalTractors() {
    return getTractorsByStatus(TractorStatus.critical);
  }

  // Get warning tractors
  List<Tractor> getWarningTractors() {
    return getTractorsByStatus(TractorStatus.warning);
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