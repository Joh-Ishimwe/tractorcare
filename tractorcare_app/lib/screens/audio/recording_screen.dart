import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/audio_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/tractor_provider.dart';
import '../../models/tractor.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/offline_sync_service.dart';
import '../../models/audio_prediction.dart';
import '../../widgets/feedback_helper.dart';
import 'dart:convert';

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
  OfflineSyncService? _offlineSyncService;
  
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _tractorId = args['tractor_id'] as String;
    _engineHours = args['engine_hours'] as double;
    
    // Set up connectivity listener
    if (_offlineSyncService == null) {
      _offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
      _offlineSyncService!.addListener(_onConnectivityChanged);
    }
    
    // Load recent predictions
    _loadRecentPredictions();
  }

  void _onConnectivityChanged() {
    if (_offlineSyncService?.isOnline == true) {
      AppConfig.log('📶 Recording screen: Connection restored, refreshing predictions...');
      _loadRecentPredictions();
      
      // Process any pending audio uploads if there are any
      _processPendingAudioUploads();
    }
  }

  Future<void> _processPendingAudioUploads() async {
    try {
      final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
      
      // Trigger sync of pending items (which includes audio uploads)
      if (offlineSyncService.isOnline) {
        AppConfig.log('📤 Processing pending audio uploads via sync service...');
        final synced = await offlineSyncService.syncPendingChanges();
        if (synced) {
          AppConfig.log('✅ Pending audio uploads synced successfully');
          // Refresh predictions after sync
          await _loadRecentPredictions();
        }
      }
    } catch (e) {
      AppConfig.logError('Failed to process pending audio uploads', e);
    }
  }

  @override
  void didUpdateWidget(covariant RecordingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh predictions when returning to this screen
    _loadRecentPredictions();
  }

  Future<void> _loadRecentPredictions() async {
    if (_isLoadingPredictions) return;
    
    setState(() => _isLoadingPredictions = true);
    
    final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
    
    try {
      if (offlineSyncService.isOnline) {
        // Online: Fetch from API and cache
        final predictions = await _apiService.getPredictions(_tractorId);
        final predictionList = (predictions as List<AudioPrediction>?)
            ?.take(3) // Show only last 3 predictions
            .toList() ?? [];
        
        // Cache the predictions
        await _storageService.setString('recent_predictions_$_tractorId', 
            jsonEncode(predictionList.map((p) => p.toJson()).toList()));
        
        if (mounted) {
          setState(() {
            _recentPredictions = predictionList;
          });
        }
      } else {
        // Offline: Load from cache
        await _loadCachedPredictions();
      }
    } catch (e) {
      AppConfig.logError('Failed to load recent predictions', e);
      // Fall back to cached data on error
      await _loadCachedPredictions();
    } finally {
      if (mounted) setState(() => _isLoadingPredictions = false);
    }
  }

  Future<void> _loadCachedPredictions() async {
    try {
      final cachedData = await _storageService.getString('recent_predictions_$_tractorId');
      if (cachedData != null) {
        final predictionsData = jsonDecode(cachedData) as List;
        final predictions = predictionsData
            .map((data) => AudioPrediction.fromJson(data))
            .toList();
        
        if (mounted) {
          setState(() {
            _recentPredictions = predictions;
          });
        }
        AppConfig.log('Loaded ${predictions.length} cached predictions');
      }
    } catch (e) {
      AppConfig.logError('Failed to load cached predictions', e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _offlineSyncService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> _startRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    // Request permission and start recording
    final success = await audioProvider.startRecording();
    
    if (!success) {
      // Permission denied or recording failed
      final errorMessage = audioProvider.error ?? 'Failed to start recording';
      if (mounted) {
        FeedbackHelper.showError(
          context, 
          kIsWeb 
            ? 'Microphone access denied. Please allow microphone access in your browser settings and try again.'
            : FeedbackHelper.formatErrorMessage(errorMessage),
        );
      }
      return;
    }
    
    setState(() {
      _isRecording = true;
      _recordingDuration = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingDuration++);
        if (_recordingDuration >= 30) {
          timer.cancel();
          _stopRecording();
        }
      } else {
        timer.cancel();
      }
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
    
    final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
    
    try {
      if (offlineSyncService.isOnline) {
        // Online: Direct upload - show status on same screen, no dialog
        try {
          final prediction = await _apiService.predictAudio(
            audioFile: kIsWeb ? null : File(filePath),
            tractorId: _tractorId,
            engineHours: _engineHours,
          );
          
          await _handleSuccessfulPrediction(prediction);
          FeedbackHelper.showSuccess(context, 'Sound analysis completed successfully!');
        } catch (e) {
          AppConfig.logError('Audio upload failed', e);
          // If we're online but upload failed, also queue it
          await _queueAudioForUpload(filePath, null, null);
          FeedbackHelper.showWarning(context, 'Analysis failed. Audio queued for retry when connection improves.');
        }
      } else {
        // Offline: Queue for later upload
        await _queueAudioForUpload(filePath, null, null);
        FeedbackHelper.showInfo(context, 'Offline mode: Audio recorded and will be analyzed when online.');
      }
    } catch (e) {
      AppConfig.logError('Audio upload failed', e);
      if (offlineSyncService.isOnline) {
        // If we're online but upload failed, also queue it
        await _queueAudioForUpload(filePath, null, null);
        FeedbackHelper.showWarning(context, 'Analysis failed. Audio queued for retry when connection improves.');
      } else {
        FeedbackHelper.showInfo(context, 'Offline mode: Audio recorded and will be analyzed when online.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleSuccessfulPrediction(AudioPrediction prediction) async {
    if (mounted) {
      // Insert into recent predictions so UI reflects immediately
      setState(() {
        _recentPredictions.insert(0, prediction);
        if (_recentPredictions.length > 3) _recentPredictions = _recentPredictions.take(3).toList();
      });
      
      // Cache the updated predictions
      await _storageService.setString('recent_predictions_$_tractorId', 
          jsonEncode(_recentPredictions.map((p) => p.toJson()).toList()));
      
      // Auto-create maintenance task if abnormal sound detected
      if (prediction.predictionClass == PredictionClass.abnormal) {
        await _createAbnormalSoundMaintenanceTask(prediction);
      }
      
      await Navigator.pushNamed(
        context,
        '/audio-results',
        arguments: {
          'prediction': prediction,
          'tractor_id': _tractorId,
          'engine_hours': _engineHours,
          'recording_duration': _recordingDuration,
        },
      );
      
      // Refresh predictions when returning from results screen
      if (mounted) {
        _loadRecentPredictions();
      }
    }
  }

  Future<void> _createAbnormalSoundMaintenanceTask(AudioPrediction prediction) async {
    try {
      final maintenanceProvider = Provider.of<MaintenanceProvider>(context, listen: false);
      
      debugPrint('🚨 Abnormal sound detected! Creating maintenance task...');
      
      final success = await maintenanceProvider.createAbnormalSoundTask(_tractorId, prediction);
      
      if (success && mounted) {
        // Show a subtle notification that task was created
        FeedbackHelper.showSuccess(
          context, 
          '🚨 Inspection task created due to abnormal sound detection',
          onAction: () {
            // Navigate to maintenance screen
            Navigator.pushNamed(context, '/maintenance');
          },
          actionLabel: 'VIEW',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to create abnormal sound maintenance task: $e');
      // Don't show error to user as this is an automatic process
    }
  }

  Future<void> _queueAudioForUpload(String? filePath, Uint8List? audioBytes, String? fileName) async {
    try {
      final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
      final storage = StorageService();
      
      // Convert audio bytes to base64 for storage
      String? base64Audio;
      if (audioBytes != null) {
        base64Audio = base64Encode(audioBytes);
      } else if (filePath != null && !kIsWeb) {
        // For mobile, read file and convert to base64
        try {
          final file = File(filePath);
          if (await file.exists()) {
            final fileBytes = await file.readAsBytes();
            base64Audio = base64Encode(fileBytes);
          }
        } catch (e) {
          AppConfig.logError('Failed to read audio file for queuing', e);
        }
      }
      
      if (base64Audio == null && filePath == null) {
        AppConfig.logError('Cannot queue audio: no audio data available', null);
        return;
      }
      
      // Create pending sync item
      final audioId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
      final pendingItems = await storage.getPendingSyncItems();
      
      pendingItems.add({
        'type': 'audio_upload',
        'tractor_id': _tractorId,
        'engine_hours': _engineHours,
        'filename': fileName ?? (filePath != null ? filePath.split('/').last : 'recording.wav'),
        'audio_data': base64Audio ?? '',
        'file_path': filePath, // Keep file path for mobile
        'timestamp': DateTime.now().toIso8601String(),
        'id': audioId,
        'pending_sync_id': audioId,
      });
      
      await storage.savePendingSyncItems(pendingItems);
      await offlineSyncService.refreshConnectivity(); // Update pending count
      
      // Add to recent predictions immediately with pending status
      final pendingAudioPrediction = AudioPrediction(
        id: audioId,
        tractorId: _tractorId,
        userId: '', // Will be populated when synced
        audioPath: filePath ?? fileName ?? 'recorded_audio',
        predictionClass: PredictionClass.unknown,
        confidence: 0.0,
        anomalyScore: 0.0,
        anomalyType: AnomalyType.unknown,
        engineHours: _engineHours,
        createdAt: DateTime.now(),
      );
      
      setState(() {
        _recentPredictions.insert(0, pendingAudioPrediction);
        if (_recentPredictions.length > 3) _recentPredictions = _recentPredictions.take(3).toList();
      });
      
      // Cache the updated predictions
      await _storageService.setString('recent_predictions_$_tractorId', 
          jsonEncode(_recentPredictions.map((p) => p.toJson()).toList()));
      
      AppConfig.log('✅ Audio queued for upload: $audioId');
    } catch (e) {
      AppConfig.logError('Failed to queue audio for upload', e);
    }
  }


  Future<void> _uploadAudioWeb(Uint8List audioBytes, String fileName) async {
    setState(() => _isUploading = true);
    
    final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
    
    try {
      if (offlineSyncService.isOnline) {
        // Online: Direct upload - show status on same screen, no dialog
        try {
          final prediction = await _apiService.predictAudio(
            audioBytes: audioBytes,
            fileName: fileName,
            tractorId: _tractorId,
            engineHours: _engineHours,
          );
          
          await _handleSuccessfulPrediction(prediction);
          FeedbackHelper.showSuccess(context, 'Sound analysis completed successfully!');
        } catch (e) {
          AppConfig.logError('Audio upload failed', e);
          // If we're online but upload failed, also queue it
          await _queueAudioForUpload(null, audioBytes, fileName);
          FeedbackHelper.showWarning(context, 'Analysis failed. Audio queued for retry when connection improves.');
        }
      } else {
        // Offline: Queue for later upload
        await _queueAudioForUpload(null, audioBytes, fileName);
        FeedbackHelper.showInfo(context, 'Offline mode: Audio recorded and will be analyzed when online.');
      }
    } catch (e) {
      AppConfig.logError('Audio upload failed', e);
      if (offlineSyncService.isOnline) {
        // If we're online but upload failed, also queue it
        await _queueAudioForUpload(null, audioBytes, fileName);
        FeedbackHelper.showWarning(context, 'Analysis failed. Audio queued for retry when connection improves.');
      } else {
        FeedbackHelper.showInfo(context, 'Offline mode: Audio recorded and will be analyzed when online.');
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
    FeedbackHelper.showError(context, FeedbackHelper.formatErrorMessage(message));
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

  Color _getStatusColor(TractorStatus status) {
    switch (status) {
      case TractorStatus.good:
        return AppColors.success;
      case TractorStatus.warning:
        return AppColors.warning;
      case TractorStatus.critical:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Map<String, dynamic> _getStatusGradientColors(TractorStatus status) {
    switch (status) {
      case TractorStatus.good:
        return {
          'gradient': [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
          'shadow': AppColors.success,
        };
      case TractorStatus.warning:
        return {
          'gradient': [
            const Color(0xFFFFB347), // Light orange
            const Color(0xFFFF8C42), // Darker orange
          ],
          'shadow': AppColors.warning,
        };
      case TractorStatus.critical:
        return {
          'gradient': [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
          'shadow': AppColors.error,
        };
      default:
        return {
          'gradient': [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          'shadow': AppColors.primary,
        };
    }
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
        actions: [
          // Connection status indicator
          Consumer<OfflineSyncService>(
            builder: (context, offlineSync, child) {
              return IconButton(
                icon: Icon(
                  offlineSync.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: offlineSync.isOnline ? Colors.green : Colors.orange,
                ),
                onPressed: () async {
                  await offlineSync.refreshConnectivity();
                  if (offlineSync.isOnline) {
                    await _loadRecentPredictions();
                  }
                },
                tooltip: offlineSync.isOnline ? 'Online' : 'Offline - recordings will be queued',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Tractor Info Header (Dynamic color based on health status)
              Consumer<TractorProvider>(
                builder: (context, tractorProvider, child) {
                  final tractor = tractorProvider.getTractorById(_tractorId);
                  final statusColor = _getStatusColor(tractor?.status ?? TractorStatus.unknown);
                  final statusGradient = _getStatusGradientColors(tractor?.status ?? TractorStatus.unknown);
                  
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: statusGradient['gradient'] as List<Color>,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (statusGradient['shadow'] as Color).withValues(alpha: 0.2),
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
                  );
                },
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
                    if (kIsWeb) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.info,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Web: Allow microphone access when prompted',
                            style: TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    
                    // Status text with loading indicator when analyzing
                    if (_isUploading && !_isRecording) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getRecordingStatusText(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        _getRecordingStatusText(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    
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
                          label: Text(kIsWeb ? 'Record Live (Web)' : 'Start Recording'),
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
                        Row(
                          children: [
                            Consumer<OfflineSyncService>(
                              builder: (context, offlineSync, child) {
                                if (!offlineSync.isOnline) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Cached',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
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
                      ..._recentPredictions.map((prediction) => GestureDetector(
                        onTap: () {
                          // Navigate to audio results screen with prediction data
                          Navigator.pushNamed(
                            context,
                            '/audio-results',
                            arguments: {
                              'prediction': prediction,
                              'tractor_id': _tractorId,
                              'engine_hours': _engineHours,
                              'recording_duration': prediction.durationSeconds ?? 0,
                            },
                          );
                        },
                        child: Container(
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
                                        prediction.formattedDateTime,
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
                                      FeedbackHelper.showSuccess(context, 'Prediction deleted successfully');
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
                        ),
                      )),
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