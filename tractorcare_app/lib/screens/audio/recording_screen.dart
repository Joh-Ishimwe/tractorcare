// lib/screens/audio/recording_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  late String _tractorId;
  late double _engineHours;
  
  Timer? _timer;
  int _recordingDuration = 0;
  late AnimationController _pulseController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get arguments
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _tractorId = args['tractor_id'] as String;
    _engineHours = args['engine_hours'] as double;
    
    // Start recording
    if (!_isRecording) {
      _startRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    final success = await audioProvider.startRecording();
    
    if (success) {
      setState(() => _isRecording = true);
      
      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
          audioProvider.updateRecordingDuration(_recordingDuration);
        });
        
        // Auto-stop at max duration
        if (_recordingDuration >= AppConfig.maxAudioDuration) {
          _stopRecording();
        }
      });
    } else {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(audioProvider.error ?? 'Failed to start recording'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    
    if (_recordingDuration < AppConfig.minAudioDuration) {
      _showError(
        'Recording too short. Please record for at least ${AppConfig.minAudioDuration} seconds.',
      );
      return;
    }

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final path = await audioProvider.stopRecording();

    if (!mounted) return;

    if (path != null) {
      // Upload audio
      _uploadAudio(path);
    } else {
      _showError('Failed to save recording');
      Navigator.pop(context);
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing audio...'),
              ],
            ),
          ),
        ),
      ),
    );

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    final prediction = await audioProvider.uploadAudio(
      filePath,
      _tractorId,
      _engineHours,
    );

    if (!mounted) return;

    // Close loading dialog
    Navigator.pop(context);

    if (prediction != null) {
      // Navigate to results
      Navigator.pushReplacementNamed(
        context,
        '/audio-results',
        arguments: prediction,
      );
    } else {
      _showError(audioProvider.error ?? 'Upload failed');
      Navigator.pop(context);
    }
  }

  Future<void> _cancelRecording() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Recording'),
        content: const Text(
          'Are you sure you want to cancel this recording?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await audioProvider.cancelRecording();
      
      if (!mounted) return;
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final progress = _recordingDuration / AppConfig.maxAudioDuration;
    final remainingTime = AppConfig.maxAudioDuration - _recordingDuration;

    return WillPopScope(
      onWillPop: () async {
        await _cancelRecording();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recording',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _cancelRecording,
                    ),
                  ],
                ),

                const Spacer(),

                // Waveform Animation
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 200 + (_pulseController.value * 50),
                      height: 200 + (_pulseController.value * 50),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.error,
                          ),
                          child: const Icon(
                            Icons.mic,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Timer
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.error,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Remaining Time
                Text(
                  remainingTime > 0
                      ? '$remainingTime seconds remaining'
                      : 'Maximum duration reached',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),

                const Spacer(),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Recording Tips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTip('Hold phone near the engine'),
                      _buildTip('Keep tractor at idle speed'),
                      _buildTip('Minimize background noise'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Stop Button
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _recordingDuration >= AppConfig.minAudioDuration
                        ? _stopRecording
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: Text(
                      'STOP RECORDING',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _recordingDuration >= AppConfig.minAudioDuration
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}