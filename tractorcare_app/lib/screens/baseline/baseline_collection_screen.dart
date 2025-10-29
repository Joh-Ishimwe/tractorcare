// lib/screens/baseline/baseline_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';

class BaselineCollectionScreen extends StatefulWidget {
  const BaselineCollectionScreen({Key? key}) : super(key: key);

  @override
  State<BaselineCollectionScreen> createState() =>
      _BaselineCollectionScreenState();
}

class _BaselineCollectionScreenState extends State<BaselineCollectionScreen> {
  String? _tractorId;
  int _currentSample = 0;
  final int _totalSamples = 5;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  final List<String> _recordedSamples = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get tractor ID from route arguments
    _tractorId = ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    final success = await audioProvider.startRecording();

    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });

          // Auto-stop after 10 seconds
          if (_recordingDuration >= 10) {
            _stopRecording();
          }
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start recording'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _stopRecording() async {
    _timer?.cancel();

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final filePath = await audioProvider.stopRecording();

    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });

    if (filePath != null) {
      setState(() {
        _recordedSamples.add(filePath);
        _currentSample++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sample ${_currentSample} recorded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Check if all samples collected
      if (_currentSample >= _totalSamples) {
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Baseline Collection Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'Successfully collected $_totalSamples baseline samples!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The AI will now learn your tractor\'s normal sound pattern.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              Navigator.pushNamed(context, '/baseline-status');
            },
            child: const Text('View Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentSample / _totalSamples;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Baseline'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Card
            CustomCard(
              color: AppColors.primary.withOpacity(0.1),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sample ${_currentSample + 1} of $_totalSamples',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(_currentSample / _totalSamples * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recording Area
            CustomCard(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  // Microphone Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? AppColors.error.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        size: 60,
                        color: _isRecording ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recording Status
                  Text(
                    _isRecording ? 'Recording...' : 'Ready to Record',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),

                  if (_isRecording) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_recordingDuration}s / 10s',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Record Button
                  if (!_isRecording)
                    CustomButton(
                      text: 'Start Recording',
                      icon: Icons.mic,
                      onPressed: _startRecording,
                      width: 200,
                    )
                  else
                    CustomButton(
                      text: 'Stop Recording',
                      icon: Icons.stop,
                      onPressed: _stopRecording,
                      color: AppColors.error,
                      width: 200,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            CustomCard(
              color: AppColors.info.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      const Text(
                        'Recording Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('Hold phone 1-2 feet from engine'),
                  _buildTip('Record in a quiet environment'),
                  _buildTip('Keep tractor at idle speed'),
                  _buildTip('Each recording should be 5-10 seconds'),
                  _buildTip('Collect $_totalSamples samples for best results'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Collected Samples
            if (_recordedSamples.isNotEmpty) ...[
              const Text(
                'Collected Samples',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._recordedSamples.asMap().entries.map((entry) {
                return CustomCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sample ${entry.key + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        onPressed: () {
                          setState(() {
                            _recordedSamples.removeAt(entry.key);
                            _currentSample--;
                          });
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}