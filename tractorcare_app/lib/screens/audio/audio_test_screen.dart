// lib/screens/audio/audio_test_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/tractor_provider.dart';
import '../../providers/audio_provider.dart';
import '../../models/tractor.dart';
import '../../config/colors.dart';

class AudioTestScreen extends StatefulWidget {
  const AudioTestScreen({super.key});

  @override
  State<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends State<AudioTestScreen> {
  String? _selectedTractorId;
  final _engineHoursController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadTractors();
  }

  @override
  void dispose() {
    _engineHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadTractors() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    await tractorProvider.fetchTractors();
    
    if (tractorProvider.tractors.isNotEmpty && _selectedTractorId == null) {
      setState(() {
        _selectedTractorId = tractorProvider.tractors.first.id;
        _engineHoursController.text = 
            tractorProvider.tractors.first.engineHours.toString();
      });
    }
  }

  Future<void> _startRecording() async {
    if (_selectedTractorId == null) {
      _showError('Please select a tractor first');
      return;
    }

    if (_engineHoursController.text.isEmpty) {
      _showError('Please enter current engine hours');
      return;
    }

    Navigator.pushNamed(
      context,
      '/recording',
      arguments: {
        'tractor_id': _selectedTractorId,
        'engine_hours': double.parse(_engineHoursController.text),
      },
    );
  }

  Future<void> _uploadFile() async {
    if (_selectedTractorId == null) {
      _showError('Please select a tractor first');
      return;
    }

    if (_engineHoursController.text.isEmpty) {
      _showError('Please enter current engine hours');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        _uploadAudio(filePath);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    final prediction = await audioProvider.uploadAudio(
      filePath,
      _selectedTractorId!,
      double.parse(_engineHoursController.text),
    );

    if (!mounted) return;

    if (prediction != null) {
      Navigator.pushNamed(
        context,
        '/audio-results',
        arguments: prediction,
      );
    } else {
      _showError(audioProvider.error ?? 'Upload failed');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Audio Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            const SizedBox(height: 12),

            // Instructions Card
            Card(
              color: AppColors.info.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recording Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipRow('Record for 30 seconds'),
                    // _buildTipRow('Keep the tractor at idle speed'),
                    _buildTipRow('Hold phone near the engine'),
                    _buildTipRow('Minimize background noise'),
                    // _buildTipRow('Record in a quiet environment'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Baseline Info Card
            Card(
              color: AppColors.info.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'For Best Results',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Setup a baseline for your tractor to get more accurate anomaly detection.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/baseline-setup');
                        },
                        icon: const Icon(Icons.graphic_eq, size: 18),
                        label: const Text('Setup Baseline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.info,
                          side: BorderSide(color: AppColors.info),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tractor Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Tractor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<TractorProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (provider.tractors.isEmpty) {
                          return Column(
                            children: [
                              const Text(
                                'No tractors found',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/add-tractor');
                                },
                                child: const Text('Add Tractor'),
                              ),
                            ],
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedTractorId,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.agriculture),
                          ),
                          items: provider.tractors.map((Tractor tractor) {
                            return DropdownMenuItem<String>(
                              value: tractor.id,
                              child: Text('${tractor.tractorId} - ${tractor.model}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTractorId = value;
                              final tractor = provider.tractors
                                  .firstWhere((t) => t.id == value);
                              _engineHoursController.text =
                                  tractor.engineHours.toString();
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Engine Hours Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Engine Hours',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _engineHoursController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g., 1250.5',
                        prefixIcon: Icon(Icons.access_time),
                        helperText: 'Enter the current engine hours',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Record Button
            SizedBox(
              height: 120,
              child: ElevatedButton(
                onPressed: _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.mic, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'START RECORDING',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Upload Button
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('UPLOAD AUDIO FILE'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // const SizedBox(height: 24),

            
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
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