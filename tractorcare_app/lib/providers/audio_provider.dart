import 'package:flutter/foundation.dart';
import '../models/audio_prediction.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import 'dart:io';                     // <-- normal import (ignored on web)

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

  // -----------------------------------------------------------------
  // Fetch predictions
  // -----------------------------------------------------------------
  Future<void> fetchPredictions(String? tractorId, {int limit = 10}) async {
    _setLoading(true);
    try {
      _predictions = await _api.getPredictions(tractorId ?? 'default');
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // -----------------------------------------------------------------
  // Upload audio file (path-based, for mobile/desktop)
  // -----------------------------------------------------------------
  Future<AudioPrediction?> uploadAudio(
    String filePath,
    String tractorId,
    double engineHours,
  ) async {
    _setLoading(true);
    _clearError();
    try {
      // ------------------- WEB -------------------
      if (kIsWeb ||
          filePath.startsWith('blob:') ||
          filePath.startsWith('http')) {
        final bytes = await getRecordingBytes(filePath);
        if (bytes == null) {
          throw Exception('Failed to get audio bytes');
        }

        final filename = filePath.split('/').last;
        final prediction = await _api.uploadAudioBytes(
          bytes: bytes,
          filename: filename.isEmpty ? 'recording.wav' : filename,
          tractorId: tractorId,
          engineHours: engineHours,
        );
        _currentPrediction = prediction;
        _predictions.insert(0, prediction);
        _setLoading(false);
        return prediction;
      }

      // ------------------- MOBILE / DESKTOP -------------------
      File? file;
      if (!kIsWeb) {
        file = File(filePath);               // <-- safe: dart:io File
      }

      final prediction = await _api.uploadAudio(
        audioFile: file,
        audioBytes: null,
        fileName: null,
        tractorId: tractorId,
        engineHours: engineHours,
      );
      _currentPrediction = prediction;
      _predictions.insert(0, prediction);
      _setLoading(false);
      return prediction;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Upload audio file (bytes-based, for web)
  // -----------------------------------------------------------------
  Future<AudioPrediction?> uploadAudioBytes(
    List<int> bytes,
    String filename,
    String tractorId,
    double engineHours,
  ) async {
    _setLoading(true);
    _clearError();
    try {
      final prediction = await _api.uploadAudioBytes(
        bytes: bytes,
        filename: filename,
        tractorId: tractorId,
        engineHours: engineHours,
      );
      _currentPrediction = prediction;
      _predictions.insert(0, prediction);
      _setLoading(false);
      return prediction;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Recording controls
  // -----------------------------------------------------------------
  Future<bool> startRecording() async {
    _clearError();
    try {
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

  Future<List<int>?> getRecordingBytes(String pathOrBlobUrl) async {
    return await _audioService.getRecordingBytes(pathOrBlobUrl);
  }

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

  void updateRecordingDuration(int seconds) {
    _recordingDuration = seconds;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Single prediction
  // -----------------------------------------------------------------
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

  void clearCurrentPrediction() {
    _currentPrediction = null;
    notifyListeners();
  }

  // -----------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------
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