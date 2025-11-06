import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';

class BaselineCollectionScreen extends StatefulWidget {
  const BaselineCollectionScreen({super.key});

  @override
  State<BaselineCollectionScreen> createState() =>
      _BaselineCollectionScreenState();
}

class _BaselineCollectionScreenState extends State<BaselineCollectionScreen> {
  // Baseline collection state
  int _targetSamples = 5;
  int _collectedSamples = 0;
  String _collectionStatus = 'not_started'; // not_started, establishing, ready_to_finalize, active
  bool _readyToFinalize = false;

  // Recording state
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;

  // Tractor info
  String? _tractorId;
  double? _tractorHours;

  // Loading states
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isFinalizing = false;

  // History and status
  Map<String, dynamic>? _baselineHistory;

  // Form controllers
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  String _loadCondition = 'normal';

  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tractorId == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;

      if (arguments is String) {
        _tractorId = arguments;
      } else if (arguments is Map<String, dynamic>) {
        _tractorId = arguments['tractorId'] ??
            arguments['tractor_id'] ??
            arguments['id'];
        _tractorHours = arguments['tractorHours']?.toDouble() ?? 0.0;
      } else {
        _tractorId = 'T007';
        _tractorHours = 300.0;
      }

      _hoursController.text = _tractorHours?.toString() ?? '';

      if (_tractorId != null && _tractorId!.isNotEmpty) {
        _loadBaselineStatus();
        _loadBaselineHistory();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // API Helpers
  // -----------------------------------------------------------------
  Future<void> _loadBaselineStatus() async {
    if (_tractorId == null) return;
    setState(() => _isLoading = true);
    try {
      final status = await _apiService.getBaselineStatus(_tractorId!);
      if (mounted) {
        setState(() {
          if (status['has_baseline'] == true && status['status'] == 'active') {
            _collectionStatus = 'active';
          } else {
            _collectionStatus = 'not_started';
          }
        });
      }
    } catch (e) {
      AppConfig.logError('Failed to load baseline status', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load baseline status: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBaselineHistory() async {
    if (_tractorId == null) return;
    try {
      final history = await _apiService.getBaselineHistory(_tractorId!);
      if (mounted) {
        setState(() => _baselineHistory = history);
      }
    } catch (e) {
      AppConfig.logError('Failed to load baseline history', e);
    }
  }

  Future<void> _startBaselineCollection() async {
    if (_tractorId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.startBaselineCollection(
        tractorId: _tractorId!,
        targetSamples: _targetSamples,
      );
      if (mounted) {
        setState(() {
          _collectionStatus = result['status'] ?? 'establishing';
          _collectedSamples = result['collected_samples'] ?? 0;
          _targetSamples = result['target_samples'] ?? 5;
          _readyToFinalize = result['ready_to_finalize'] == true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Baseline collection started'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      AppConfig.logError('Failed to start baseline collection', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start collection: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -----------------------------------------------------------------
  // Recording Logic
  // -----------------------------------------------------------------
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
          final fileName = 'baseline_sample_$timestamp.wav';
          await _uploadAudioSampleWeb(Uint8List.fromList(bytes), fileName);
        }
      } else {
        await _uploadAudioSample(audioPath);
      }
    }
  }

  // -----------------------------------------------------------------
  // Upload Helpers
  // -----------------------------------------------------------------
  Future<void> _uploadAudioSample(String filePath) async {
    if (_tractorId == null) return;
    setState(() => _isUploading = true);
    try {
      File? file;
      if (!kIsWeb) {
        file = File(filePath);
      }

      final result = await _apiService.addBaselineSample(
        tractorId: _tractorId!,
        audioFile: file,
        audioBytes: null,
        fileName: null,
      );

      if (mounted) {
        setState(() {
          _collectedSamples = result['collected_samples'] ?? _collectedSamples;
          _readyToFinalize = result['ready_to_finalize'] == true;
          if (_readyToFinalize) _collectionStatus = 'ready_to_finalize';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sample uploaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadBaselineStatus();
        _loadBaselineHistory();
      }
    } catch (e) {
      AppConfig.logError('Failed to upload audio sample', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadAudioSampleWeb(Uint8List audioBytes, String fileName) async {
    if (_tractorId == null) return;
    setState(() => _isUploading = true);
    try {
      final result = await _apiService.addBaselineSample(
        tractorId: _tractorId!,
        audioBytes: audioBytes,
        fileName: fileName,
      );

      if (mounted) {
        setState(() {
          _collectedSamples = result['collected_samples'] ?? _collectedSamples;
          _readyToFinalize = result['ready_to_finalize'] == true;
          if (_readyToFinalize) _collectionStatus = 'ready_to_finalize';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sample uploaded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadBaselineStatus();
        _loadBaselineHistory();
      }
    } catch (e) {
      AppConfig.logError('Failed to upload audio sample', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final platformFile = result.files.first;
      if (kIsWeb) {
        final bytes = platformFile.bytes;
        final fileName = platformFile.name;
        if (bytes != null) await _uploadAudioSampleWeb(bytes, fileName);
      } else {
        final filePath = platformFile.path;
        if (filePath != null) await _uploadAudioSample(filePath);
      }
    }
  }

  // -----------------------------------------------------------------
  // Finalize
  // -----------------------------------------------------------------
  Future<void> _finalizeBaseline() async {
    if (_tractorId == null) return;
    setState(() => _isFinalizing = true);
    try {
      final tractorHours = double.tryParse(_hoursController.text);

      final result = await _apiService.finalizeBaseline(
        tractorId: _tractorId!,
        tractorHours: tractorHours,
        loadCondition: _loadCondition,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        setState(() {
          _collectionStatus = 'active';
          _readyToFinalize = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Baseline finalized successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppConfig.logError('Failed to finalize baseline', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Finalization failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  // -----------------------------------------------------------------
  // UI Helpers
  // -----------------------------------------------------------------
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getRecordingStatusText() {
    switch (_collectionStatus) {
      case 'not_started':
        return 'Start Baseline Collection';
      case 'establishing':
        return _isRecording ? 'Recording...' : 'Ready to Record';
      case 'ready_to_finalize':
        return 'All Samples Collected!';
      case 'active':
        return 'Baseline Active';
      default:
        return 'Ready to Record';
    }
  }

  // -----------------------------------------------------------------
  // Build Methods (Now Fully Implemented)
  // -----------------------------------------------------------------
  Widget _buildProgressHeader() {
    final progressPercent = _targetSamples > 0 ? (_collectedSamples / _targetSamples) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sample $_collectedSamples of $_targetSamples',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(progressPercent * 100).toInt()}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
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
          Text(
            'Baseline Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Start/Update Baseline Button
          if (_collectionStatus == 'not_started') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startBaselineCollection,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Start Baseline Creation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ] else if (_collectionStatus == 'active') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startBaselineCollection,
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text(
                  'Update Baseline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
          
          // Finalize Baseline Button (only show if ready)
          if (_readyToFinalize) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isFinalizing ? null : _finalizeBaseline,
                icon: _isFinalizing 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isFinalizing ? 'Finalizing...' : 'Finalize Baseline',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
          
          // Status Message
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor().withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusMessage(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_collectionStatus) {
      case 'not_started':
        return AppColors.textSecondary;
      case 'active':
        return AppColors.primary;
      case 'ready_to_finalize':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon() {
    switch (_collectionStatus) {
      case 'not_started':
        return Icons.info_outline;
      case 'active':
        return Icons.mic;
      case 'ready_to_finalize':
        return Icons.warning_amber;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  String _getStatusMessage() {
    switch (_collectionStatus) {
      case 'not_started':
        return 'No baseline found. Start collecting samples to create your first baseline.';
      case 'active':
        return 'Baseline collection in progress. Collect ${5 - _collectedSamples} more samples.';
      case 'ready_to_finalize':
        return 'Ready to finalize! You have enough samples to create the baseline.';
      case 'completed':
        return 'Baseline is active and ready for analysis comparisons.';
      default:
        return 'Loading baseline status...';
    }
  }

  Widget _buildRecordingSection() {
    if (_collectionStatus == 'not_started') {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.mic_off,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Baseline Collection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a baseline collection above to begin recording samples',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
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
          
          // Recording Action Buttons
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
        ],
      ),
    );
  }

  Widget _buildFinalizeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready to Finalize',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Configure settings before finalizing',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Form Fields
          TextField(
            controller: _hoursController,
            decoration: InputDecoration(
              labelText: 'Current Engine Hours',
              hintText: 'Enter current hours',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.access_time),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: _loadCondition,
            decoration: InputDecoration(
              labelText: 'Load Condition',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.settings),
            ),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'heavy', child: Text('Heavy')),
            ],
            onChanged: (value) => setState(() => _loadCondition = value!),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any relevant notes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.note),
            ),
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 16),
          
          // Information Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use the "Finalize Baseline" button above when ready to complete the setup.',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    final history = _baselineHistory?['history'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Baseline History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                SizedBox(width: 8),
                Expanded(child: Text('No previous baselines found. Start collecting your first baseline!', style: TextStyle(color: AppColors.info))),
              ],
            ),
          )
        else
          ...history.map((baseline) => _buildHistoryItem(baseline)).toList(),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> baseline) {
    final isActive = baseline['is_active'] == true;
    final createdAt = DateTime.tryParse(baseline['created_at'] ?? '');
    final confidence = baseline['confidence']?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isActive) ...[Icon(Icons.check_circle, color: AppColors.success, size: 20), const SizedBox(width: 8)],
              Expanded(
                child: Text(
                  isActive ? 'Active Baseline' : 'Archived Baseline',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? AppColors.success : AppColors.textSecondary),
                ),
              ),
              Text('${baseline['num_samples']} samples', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text('Created ${DateFormat('MMM dd, yyyy').format(createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 4),
          Text('Engine Hours: ${baseline['tractor_hours']?.toString() ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (confidence > 0) ...[
            const SizedBox(height: 4),
            Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collect Baseline'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressHeader(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildRecordingSection(),
                  const SizedBox(height: 24),
                  if (_readyToFinalize) _buildFinalizeSection(),
                  if (_readyToFinalize) const SizedBox(height: 24),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }
}