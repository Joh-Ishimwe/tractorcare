// lib/services/audio_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  // Request microphone permission
  Future<bool> requestPermission() async {
    try {
      print('🔐 Requesting microphone permission...');
      
      // For mobile platforms, use permission_handler
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.microphone.request();
        print('📱 Mobile permission status: ${status.name}');
        return status.isGranted;
      } else {
        // For web and desktop, use recorder's permission
        final hasPermission = await _recorder.hasPermission();
        print('🌐 Web/Desktop permission: $hasPermission');
        return hasPermission;
      }
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  // Check if permission is granted
  Future<bool> hasPermission() async {
    try {
      // For mobile platforms, use permission_handler
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final status = await Permission.microphone.status;
        return status.isGranted;
      } else {
        // For web and desktop, use recorder's permission
        return await _recorder.hasPermission();
      }
    } catch (e) {
      print('❌ Error checking permission: $e');
      return false;
    }
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      print('🎤 Starting audio recording...');
      
      // Check if already recording
      if (_isRecording) {
        print('⚠️ Already recording');
        return false;
      }

      // Check and request permission
      if (!await hasPermission()) {
        print('🔐 Requesting microphone permission...');
        final granted = await requestPermission();
        if (!granted) {
          print('❌ Microphone permission denied');
          throw Exception('Microphone permission denied. Please allow microphone access in your browser settings.');
        }
      }

      // Handle path and config for different platforms
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String path;
      RecordConfig config;
      
      if (kIsWeb) {
        // Web platform - use a temporary name, recorder handles blob internally
        path = 'audio_$timestamp.wav';
        config = const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
        );
        print('🌐 Web recording');
      } else {
        // Mobile and desktop platforms - need file path
        final directory = await getTemporaryDirectory();
        
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          // Desktop platforms
          path = '${directory.path}/audio_$timestamp.wav';
          config = const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            bitRate: 128000,
          );
        } else {
          // Mobile platforms
          path = '${directory.path}/audio_$timestamp.m4a';
          config = const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            bitRate: 128000,
          );
        }
      }

      print('📁 Recording to: $path');
      print('⚙️ Config: ${config.encoder}, ${config.sampleRate}Hz');

      // Start recording
      await _recorder.start(config, path: path);

      _isRecording = true;
      _currentRecordingPath = path;

      print('✅ Recording started successfully');
      return true;
    } catch (e) {
      print('❌ Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  // Stop recording - returns path or blob URL (on web)
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

  // Get recording bytes (for web platform)
  Future<List<int>?> getRecordingBytes(String pathOrBlobUrl) async {
    try {
      if (kIsWeb) {
        // On web, pathOrBlobUrl is a blob URL, fetch it as bytes
        final response = await http.get(Uri.parse(pathOrBlobUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        return null;
      } else {
        // On mobile/desktop, read file bytes
        final file = File(pathOrBlobUrl);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      }
    } catch (e) {
      print('Error getting recording bytes: $e');
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