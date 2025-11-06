// lib/screens/audio/recording_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../models/audio_prediction.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late String _tractorId;
  late double _engineHours;
  
  Timer? _timer;
  int _recordingDuration = 0;
  bool _isRecording = false;
  bool _isUploading = false;
  List<AudioPrediction> _recentPredictions = [];
  bool _isLoadingPredictions = false;
  
  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _tractorId = args['tractor_id'] as String;
    _engineHours = args['engine_hours'] as double;
    
    // Load recent predictions
    _loadRecentPredictions();
  }

  Future<void> _loadRecentPredictions() async {
    if (_isLoadingPredictions) return;
    
    setState(() => _isLoadingPredictions = true);
    
    try {
      final predictions = await _apiService.getPredictions(_tractorId);
      if (mounted) {
        setState(() {
          _recentPredictions = (predictions as List<AudioPrediction>?)
              ?.take(3) // Show only last 3 predictions
              .toList() ?? [];
        });
      }
    } catch (e) {
      AppConfig.logError('Failed to load recent predictions', e);
    } finally {
      if (mounted) setState(() => _isLoadingPredictions = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
    });
    audioProvider.startRecording();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
      if (_recordingDuration >= 30) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    setState(() => _isRecording = false);

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final audioPath = await audioProvider.stopRecording();

    if (audioPath != null) {
      if (kIsWeb) {
        final bytes = await audioProvider.getRecordingBytes(audioPath);
        if (bytes != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'test_sound_$timestamp.wav';
          await _uploadAudioWeb(Uint8List.fromList(bytes), fileName);
        }
      } else {
        await _uploadAudio(audioPath);
      }
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    setState(() => _isUploading = true);
    try {
      final prediction = await _apiService.predictAudio(
        audioFile: filePath,
        tractorId: _tractorId,
        engineHours: _engineHours,
      );
      
      if (mounted) {
        // Insert into recent predictions so UI reflects immediately
        setState(() {
          _recentPredictions.insert(0, prediction);
          if (_recentPredictions.length > 3) _recentPredictions = _recentPredictions.take(3).toList();
        });
        Navigator.pushReplacementNamed(
          context,
          '/audio-results',
          arguments: {
            'prediction': prediction,
            'tractor_id': _tractorId,
            'engine_hours': _engineHours,
            'recording_duration': _recordingDuration,
          },
        );
      }
    } catch (e) {
      AppConfig.logError('Audio upload failed', e);
      if (mounted) {
        _showError('Analysis failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadAudioWeb(Uint8List audioBytes, String fileName) async {
    setState(() => _isUploading = true);
    try {
      final prediction = await _apiService.predictAudio(
        audioBytes: audioBytes,
        fileName: fileName,
        tractorId: _tractorId,
        engineHours: _engineHours,
      );
      
      if (mounted) {
        // Insert into recent predictions so UI reflects immediately
        setState(() {
          _recentPredictions.insert(0, prediction);
          if (_recentPredictions.length > 3) _recentPredictions = _recentPredictions.take(3).toList();
        });
        Navigator.pushReplacementNamed(
          context,
          '/audio-results',
          arguments: {
            'prediction': prediction,
            'tractor_id': _tractorId,
            'engine_hours': _engineHours,
            'recording_duration': _recordingDuration,
          },
        );
      }
    } catch (e) {
      AppConfig.logError('Audio upload failed', e);
      if (mounted) {
        _showError('Analysis failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'ogg'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        
        if (kIsWeb) {
          if (platformFile.bytes != null) {
            await _uploadAudioWeb(platformFile.bytes!, platformFile.name);
          } else {
            _showError('Unable to read file on web platform');
          }
        } else {
          if (platformFile.path != null) {
            await _uploadAudio(platformFile.path!);
          } else {
            _showError('Unable to access file path');
          }
        }
      } else {
        _showError('No file selected');
      }
    } catch (e) {
      AppConfig.logError('File selection failed', e);
      _showError('Failed to select audio file: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String _getRecordingStatusText() {
    if (_isUploading) return 'Analyzing sound...';
    if (_isRecording) return 'Recording...';
    return 'Ready to Record';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getPredictionColor(String status) {
    switch (status.toLowerCase()) {
      case 'abnormal':
      case 'warning':
        return AppColors.error;
      case 'normal':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPredictionIcon(String status) {
    switch (status.toLowerCase()) {
      case 'abnormal':
      case 'warning':
        return Icons.warning;
      case 'normal':
        return Icons.check_circle;
      default:
        return Icons.analytics;
    }
  }

  String _getPredictionTitle(String status) {
    switch (status.toLowerCase()) {
      case 'abnormal':
        return 'Abnormal Sound Detected';
      case 'warning':
        return 'Warning - Check Required';
      case 'normal':
        return 'Normal Operation';
      default:
        return 'Analysis Complete';
    }
  }

  // removed unused _formatDate

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Test Sound'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Tractor Info Header (Green background like baseline collection)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.agriculture,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Sound',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tractor $_tractorId',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Engine Hours: ${_engineHours.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recording Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recording Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.info,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Hold phone near the engine'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Keep tractor at idle speed'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Minimize background noise'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recording Section (Same style as baseline collection)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Recording Button
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isRecording ? AppColors.error : AppColors.success,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 48,
                          color: _isRecording ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      _getRecordingStatusText(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    
                    if (_isRecording) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    if (!_isRecording) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _startRecording,
                          icon: const Icon(Icons.mic),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _uploadAudioFile,
                          icon: _isUploading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(_isUploading ? 'Uploading...' : 'Upload Audio File'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    if (_isUploading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Analyzing engine sound...'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recent Predictions/Uploads Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Predictions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to full history
                          },
                          child: Text(
                            'View All',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Recent predictions list or placeholder
                    if (_isLoadingPredictions) ...[
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ] else if (_recentPredictions.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              color: AppColors.textSecondary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No recent predictions yet',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._recentPredictions.map((prediction) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              width: 4,
                              color: _getPredictionColor(prediction.predictionClass.name),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getPredictionIcon(prediction.predictionClass.name),
                              color: _getPredictionColor(prediction.predictionClass.name),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPredictionTitle(prediction.predictionClass.name),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Additional details: recorded_at, duration, deviation
                                  Row(
                                    children: [
                                      Text(
                                        '${prediction.formattedDateTime}',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(width: 8),
                                      if (prediction.durationSeconds != null) ...[
                                        Text('Duration: ${prediction.durationSeconds}s', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        const SizedBox(width: 8),
                                      ],
                                      if (prediction.baselineDeviation != null) ...[
                                        Text('Δ: ${prediction.baselineDeviation!.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Delete icon
                            IconButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Prediction'),
                                    content: const Text('Delete this prediction? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await _apiService.deletePrediction(tractorId: _tractorId, predictionId: prediction.id);
                                    if (mounted) {
                                      setState(() => _recentPredictions.removeWhere((p) => p.id == prediction.id));
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Prediction deleted'), backgroundColor: AppColors.success));
                                    }
                                  } catch (e) {
                                    AppConfig.logError('Failed to delete prediction', e);
                                    if (mounted) _showError('Failed to delete prediction');
                                  }
                                }
                              },
                              icon: Icon(Icons.delete_outline, color: AppColors.error),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}