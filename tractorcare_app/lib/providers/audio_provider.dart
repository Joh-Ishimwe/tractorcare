// lib/providers/audio_provider.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/audio_prediction.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class AudioProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final AudioService _audioService = AudioService();

  List<AudioPrediction> _predictions = [];
  AudioPrediction? _currentPrediction;
  bool _isLoading = false;
  bool _isRecording = false;
  int _recordingDuration = 0;
  String? _error;

  List<AudioPrediction> get predictions => _predictions;
  AudioPrediction? get currentPrediction => _currentPrediction;
  bool get isLoading => _isLoading;
  bool get isRecording => _isRecording;
  int get recordingDuration => _recordingDuration;
  String? get error => _error;

  // Fetch predictions
  Future<void> fetchPredictions(String? tractorId, {int limit = 10}) async {
    _setLoading(true);

    try {
      _predictions = await _api.getPredictions(
        tractorId: tractorId,
        limit: limit,
      );
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Upload audio file
  Future<AudioPrediction?> uploadAudio(
    String filePath,
    String tractorId,
    double engineHours,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final file = File(filePath);
      
      final prediction = await _api.uploadAudio(
        file,
        tractorId,
        engineHours,
      );

      _currentPrediction = prediction;
      
      // Add to predictions list
      _predictions.insert(0, prediction);
      
      _setLoading(false);
      return prediction;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // Start recording
  Future<bool> startRecording() async {
    _clearError();

    try {
      // Request permission if needed
      if (!await _audioService.hasPermission()) {
        final granted = await _audioService.requestPermission();
        if (!granted) {
          _setError('Microphone permission denied');
          return false;
        }
      }

      final success = await _audioService.startRecording();
      
      if (success) {
        _isRecording = true;
        _recordingDuration = 0;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      final path = await _audioService.stopRecording();
      _isRecording = false;
      _recordingDuration = 0;
      notifyListeners();
      return path;
    } catch (e) {
      _setError(e.toString());
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      await _audioService.cancelRecording();
      _isRecording = false;
      _recordingDuration = 0;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Update recording duration
  void updateRecordingDuration(int seconds) {
    _recordingDuration = seconds;
    notifyListeners();
  }

  // Get prediction by ID
  Future<AudioPrediction?> getPrediction(String predictionId) async {
    _setLoading(true);

    try {
      final prediction = await _api.getPrediction(predictionId);
      _currentPrediction = prediction;
      _setLoading(false);
      return prediction;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // Clear current prediction
  void clearCurrentPrediction() {
    _currentPrediction = null;
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

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}