// lib/screens/record_audio_screen.dart

import 'package:flutter/material.dart';
import '../theme.dart';

class RecordAudioScreen extends StatefulWidget {
  const RecordAudioScreen({super.key});

  @override
  State<RecordAudioScreen> createState() => _RecordAudioScreenState();
}

class _RecordAudioScreenState extends State<RecordAudioScreen> {
  bool _isRecording = false;
  int _recordingSeconds = 0;

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (!_isRecording) {
        _recordingSeconds = 0;
      }
    });

    if (_isRecording) {
      // Simulate recording timer
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    }
  }

  void _updateTimer() {
    if (_isRecording && mounted) {
      setState(() {
        _recordingSeconds++;
      });
      if (_recordingSeconds < 10) {
        Future.delayed(const Duration(seconds: 1), _updateTimer);
      } else {
        // Auto-stop after 10 seconds
        _toggleRecording();
        _showResults();
      }
    }
  }

  void _showResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Status: Normal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: 87%',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Engine Sound'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'How to Record',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Start your tractor engine\n'
                      '2. Place phone near engine\n'
                      '3. Press record button\n'
                      '4. Record for 10 seconds',
                      style: TextStyle(color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Recording Button
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? AppColors.error : AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? AppColors.error : AppColors.primary).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Text
            Text(
              _isRecording ? 'Recording: ${_recordingSeconds}s / 10s' : 'Tap to Start Recording',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),

            // Progress
            if (_isRecording)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _recordingSeconds / 10,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keep phone steady...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
