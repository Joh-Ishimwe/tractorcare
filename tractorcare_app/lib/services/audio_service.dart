// lib/services/audio_service.dart

import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Check if permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          throw Exception('Microphone permission denied');
        }
      }

      // Check if already recording
      if (_isRecording) {
        return false;
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/audio_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _isRecording = true;
      _currentRecordingPath = path;

      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;

      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;

        // Delete the recording file
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
      _isRecording = false;
    } finally {
      _currentRecordingPath = null;
    }
  }

  // Pause recording
  Future<void> pauseRecording() async {
    try {
      if (_isRecording) {
        await _recorder.pause();
      }
    } catch (e) {
      print('Error pausing recording: $e');
    }
  }

  // Resume recording
  Future<void> resumeRecording() async {
    try {
      if (_isRecording) {
        await _recorder.resume();
      }
    } catch (e) {
      print('Error resuming recording: $e');
    }
  }

  // Check if recording is supported
  Future<bool> isRecordingSupported() async {
    return await _recorder.hasPermission();
  }

  // Dispose
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    _recorder.dispose();
  }

  // Get recording duration
  Future<int> getRecordingDuration() async {
    // This would require additional logic to track duration
    // For now, return 0
    return 0;
  }

  // Validate audio file
  Future<bool> validateAudioFile(String path) async {
    try {
      final file = File(path);
      
      // Check if file exists
      if (!await file.exists()) {
        return false;
      }

      // Check file size (should be more than 1KB)
      final size = await file.length();
      if (size < 1024) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating audio file: $e');
      return false;
    }
  }

  // Get audio file size
  Future<int> getAudioFileSize(String path) async {
    try {
      final file = File(path);
      return await file.length();
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  // Delete audio file
  Future<void> deleteAudioFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting audio file: $e');
    }
  }
}