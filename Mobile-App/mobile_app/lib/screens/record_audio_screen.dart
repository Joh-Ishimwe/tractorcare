// lib/screens/record_audio_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RecordAudioScreen extends StatefulWidget {
  const RecordAudioScreen({super.key});

  @override
  State<RecordAudioScreen> createState() => _RecordAudioScreenState();
}

class _RecordAudioScreenState extends State<RecordAudioScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  
  bool _isRecording = false;
  bool _isUploading = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _audioPath;
  Map<String, dynamic>? _predictionResult;

  static const int maxDuration = 10; // 10 seconds

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      if (await Permission.microphone.request().isGranted) {
        // Get temporary directory
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/engine_sound_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Start recording
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
          _audioPath = path;
          _predictionResult = null;
        });

        // Start timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });

          // Auto-stop at max duration
          if (_recordDuration >= maxDuration) {
            _stopRecording();
          }
        });
      } else {
        _showSnackBar('Microphone permission denied');
      }
    } catch (e) {
      _showSnackBar('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });

      if (path != null) {
        _showSnackBar('Recording saved! Tap "Analyze" to get prediction.');
      }
    } catch (e) {
      _showSnackBar('Error stopping recording: $e');
    }
  }

  Future<void> _uploadAndAnalyze() async {
    if (_audioPath == null) {
      _showSnackBar('No recording to analyze');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final File audioFile = File(_audioPath!);
      final result = await _apiService.uploadAudio(audioFile);

      setState(() {
        _predictionResult = result;
        _isUploading = false;
      });

      _showSnackBar('Analysis complete!');
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar('Error analyzing audio: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Color _getPredictionColor(String prediction) {
    return prediction.toLowerCase() == 'normal' ? AppColors.success : AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Record Engine Sound'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionsCard(),
            const SizedBox(height: 24),
            _buildRecordingInterface(),
            const SizedBox(height: 24),

            if (!_isRecording && _audioPath == null)
              _buildStartButton(),
            
            if (_isRecording)
              _buildStopButton(),
            
            if (!_isRecording && _audioPath != null && _predictionResult == null)
              Column(
                children: [
                  _buildAnalyzeButton(),
                  const SizedBox(height: 12),
                  _buildRetryButton(),
                ],
              ),

            if (_predictionResult != null) ...[
              const SizedBox(height: 24),
              _buildPredictionResult(),
              const SizedBox(height: 12),
              _buildRetryButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to Record',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInstructionStep('1', '👂', 'Start the tractor engine'),
          _buildInstructionStep('2', '📍', 'Stand 1 meter away from engine'),
          _buildInstructionStep('3', '⏱️', 'Record for 10 seconds'),
          _buildInstructionStep('4', '🔇', 'Keep background noise minimal'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingInterface() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? 'Recording...' : 'Ready to Record',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          if (_isRecording) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _recordDuration / maxDuration,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton.icon(
      onPressed: _startRecording,
      icon: const Icon(Icons.mic, size: 28),
      label: const Text(
        'START RECORDING',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return ElevatedButton.icon(
      onPressed: _stopRecording,
      icon: const Icon(Icons.stop, size: 28),
      label: const Text(
        'STOP RECORDING',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
  backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton.icon(
      onPressed: _isUploading ? null : _uploadAndAnalyze,
      icon: _isUploading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.analytics, size: 28),
      label: Text(
        _isUploading ? 'ANALYZING...' : 'ANALYZE SOUND',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
  backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _audioPath = null;
          _predictionResult = null;
          _recordDuration = 0;
        });
      },
      icon: const Icon(Icons.refresh),
      label: const Text('RECORD AGAIN'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPredictionResult() {
    final prediction = _predictionResult!['prediction_class'] as String;
    final confidence = (_predictionResult!['confidence'] as num).toDouble();
    final modelUsed = _predictionResult!['model_used'] as String;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPredictionColor(prediction),
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Icon(
            prediction.toLowerCase() == 'normal'
                ? Icons.check_circle
                : Icons.warning,
            size: 64,
            color: _getPredictionColor(prediction),
          ),
          const SizedBox(height: 16),
          Text(
            prediction.toUpperCase(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _getPredictionColor(prediction),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Model: $modelUsed',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPredictionColor(prediction).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              prediction.toLowerCase() == 'normal'
                  ? '✓ Engine sounds healthy. Continue normal operation.'
                  : '⚠ Abnormal sound detected. Consider inspection.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}