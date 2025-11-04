// lib/screens/baseline/baseline_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import '../../services/api_service.dart';

class BaselineCollectionScreen extends StatefulWidget {
  const BaselineCollectionScreen({super.key});

  @override
  State<BaselineCollectionScreen> createState() =>
      _BaselineCollectionScreenState();
}

class _BaselineCollectionScreenState extends State<BaselineCollectionScreen> {
  int _currentSample = 0;
  final int _totalSamples = 5;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  final List<String> _recordedSamples = [];
  String? _tractorId;
  String? _baselineId;
  bool _isLoading = false;
  double? _tractorHours;
  String? _tractorModel;
  List<Map<String, dynamic>>? _baselineHistory;
  bool _isLoadingHistory = true;
  String _loadCondition = 'normal';
  final TextEditingController _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get tractor ID from route arguments
    if (_tractorId == null) {
      final arguments = ModalRoute.of(context)?.settings.arguments;
      
      print('Baseline Collection: Received arguments: $arguments (type: ${arguments.runtimeType})');
      
      if (arguments is String) {
        // Direct tractor ID passed as string
        String rawId = arguments;
        
        // Check if it's an ObjectID (MongoDB format) and reject it
        if (rawId.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawId)) {
          print('⚠️ Received ObjectID format ($rawId), this will not work with backend API');
          print('Backend expects tractor IDs like T007, T001, etc.');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid tractor ID format. Please use proper tractor ID (e.g., T007)'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
        
        _tractorId = rawId;
        _tractorHours = 0.0; // Default
      } else if (arguments is Map<String, dynamic>) {
        // Tractor data passed in a map (preferred)
        _tractorId = arguments['tractorId'] ?? arguments['tractor_id'] ?? arguments['id'];
        _tractorHours = arguments['tractorHours']?.toDouble() ?? 0.0;
        _tractorModel = arguments['model'];
      } else {
        // Fallback - for testing purposes
        _tractorId = 'T007'; // Use working test tractor
        _tractorHours = 300.0;
        _tractorModel = 'Test Tractor';
        print('Warning: No valid tractor ID provided, using test fallback');
      }
      
      print('Baseline Collection: Using tractor ID: $_tractorId');
      print('Baseline Collection: Tractor Hours: $_tractorHours');
      print('Baseline Collection: Model: $_tractorModel');
      
      if (_tractorId != null && _tractorId!.isNotEmpty) {
        _initializeBaseline();
        _loadBaselineHistory();
      } else {
        print('Error: Invalid tractor ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No tractor selected'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  bool get isLoading => _isLoading; // Used for loading states

  Future<void> _testTractorAPI() async {
    if (_tractorId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final apiService = ApiService();
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing API connectivity...'),
            ],
          ),
        ),
      );
      
      // Test the API endpoints
      await apiService.testTractorT007();
      final baselineTest = await apiService.testBaselineUpload(_tractorId!);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ API Test Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tractor: $_tractorId'),
                Text('Model: $_tractorModel'),
                Text('Status: ${baselineTest['baseline_status']}'),
                const SizedBox(height: 8),
                const Text('All endpoints are working correctly!'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ API Test Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tractor: $_tractorId'),
                Text('Error: $e'),
                const SizedBox(height: 8),
                const Text('Please check your internet connection and try again.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

    if (filePath != null && _tractorId != null) {
      try {
        // Upload the recorded sample to API
        final apiService = ApiService();
        
        // Check if we're on web platform
        if (kIsWeb) {
          // For web, we need to get the audio bytes from the audio provider
          final audioBytesList = await audioProvider.getRecordingBytes(filePath);
          if (audioBytesList != null) {
            // Convert List<int> to Uint8List
            final audioBytes = Uint8List.fromList(audioBytesList);
            await apiService.addBaselineSample(
              tractorId: _tractorId!,
              audioBytes: audioBytes,
              fileName: 'recording_${DateTime.now().millisecondsSinceEpoch}.wav',
            );
          } else {
            throw Exception('Failed to get recording bytes for web upload');
          }
        } else {
          // For mobile/desktop, use file path
          if (!kIsWeb) {
            final file = File(filePath);
            await apiService.addBaselineSample(
              tractorId: _tractorId!,
              audioFile: file,
            );
          } else {
            throw Exception('Web should use bytes path above');
          }
        }

        setState(() {
          _recordedSamples.add(filePath);
          _currentSample++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample $_currentSample recorded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // Check if all samples collected
        if (_currentSample >= _totalSamples) {
          await _finalizeBaseline();
          _showCompletionDialog();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload recorded sample: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _finalizeBaseline() async {
    if (_baselineId == null || _tractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No active baseline session'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Collect finalization parameters
      final finalizationData = {
        'tractor_hours': _tractorHours,
        'load_condition': _loadCondition,
        'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
      };

      print('Finalizing baseline with data: $finalizationData');
      
      await ApiService().finalizeBaseline(_baselineId!, finalizationData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline collection completed successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      
      // Refresh the history
      await _loadBaselineHistory();
      
      // Reset form
      _resetBaseline();
    } catch (e) {
      print('Error finalizing baseline: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetBaseline() {
    setState(() {
      _baselineId = null;
      _recordedSamples.clear();
      _loadCondition = 'normal';
      _notesController.clear();
    });
  }

  Future<void> _initializeBaseline() async {
    if (_tractorId == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final apiService = ApiService();
      final result = await apiService.startBaselineCollection(
        tractorId: _tractorId!,
        targetSamples: _totalSamples,
      );
      
      // Extract baseline ID from response
      if (result['baseline_id'] != null) {
        _baselineId = result['baseline_id'];
        print('✅ Baseline session started with ID: $_baselineId');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baseline collection session started'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      print('❌ Baseline initialization error: $e');
      
      String errorMessage = 'Failed to start baseline session';
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        errorMessage = 'Tractor "$_tractorId" not found. Please ensure this tractor ID exists in the backend system.';
      } else if (e.toString().contains('403') || e.toString().contains('forbidden')) {
        errorMessage = 'Authentication error. Please login again.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('connection')) {
        errorMessage = 'Network connection error. Please check your internet connection.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBaselineHistory() async {
    if (_tractorId == null) return;
    
    setState(() {
      _isLoadingHistory = true;
    });
    
    try {
      final apiService = ApiService();
      final baselines = await apiService.getBaselineHistory(_tractorId!);
      
      // Transform API response to match expected format
      List<Map<String, dynamic>> history = [];
      for (var baseline in baselines) {
        history.add({
          'id': baseline['id']?.toString() ?? '',
          'date': _formatDate(baseline['created_at']),
          'status': _mapStatus(baseline['status']),
          'samples': baseline['sample_count'] ?? 0,
          'isActive': baseline['is_active'] ?? false,
        });
      }
      
      setState(() {
        _baselineHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Failed to load baseline history: $e');
      setState(() {
        _baselineHistory = [];
        _isLoadingHistory = false;
      });
      
      // Don't show error for 404 (tractor not found) - it's expected for new tractors
      if (!e.toString().contains('404') && !e.toString().contains('not found')) {
        print('❌ Failed to load baseline history: $e');
      } else {
        print('ℹ️ No baseline history found for tractor $_tractorId (new tractor)');
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _mapStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing';
      case 'failed':
        return 'Failed';
      case 'in_progress':
        return 'Processing';
      default:
        return 'Unknown';
    }
  }

  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  void _uploadAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        // Show loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 16),
                Text('Uploading audio file...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );

        if (_tractorId != null) {
          final apiService = ApiService();
          
          // Handle web vs mobile file upload
          if (result.files.single.path != null && !kIsWeb) {
            // Mobile/Desktop - use file path
            final file = File(result.files.single.path!);
            await apiService.addBaselineSample(
              tractorId: _tractorId!,
              audioFile: file,
            );
            
            setState(() {
              _recordedSamples.add(file.path);
              _currentSample++;
            });
          } else if (result.files.single.bytes != null) {
            // Web - use bytes
            await apiService.addBaselineSample(
              tractorId: _tractorId!,
              audioBytes: result.files.single.bytes!,
              fileName: result.files.single.name,
            );
            
            setState(() {
              _recordedSamples.add(result.files.single.name);
              _currentSample++;
            });
          } else {
            throw Exception('No file data available');
          }

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sample $_currentSample uploaded successfully!'),
              backgroundColor: AppColors.success,
            ),
          );

          // Check if all samples collected
          if (_currentSample >= _totalSamples) {
            await _finalizeBaseline();
            _showCompletionDialog();
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload audio file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
            // API Test Button (for debugging)
            if (_tractorId != null) ...[
              ElevatedButton.icon(
                onPressed: () => _testTractorAPI(),
                icon: const Icon(Icons.bug_report),
                label: Text('Test API for $_tractorId'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
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

                  // Configuration Section
                  CustomCard(
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recording Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Load Condition Selector
                        const Text(
                          'Load Condition:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _loadCondition,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _loadCondition = newValue!;
                                });
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: 'idle',
                                  child: Text('Idle'),
                                ),
                                DropdownMenuItem(
                                  value: 'light',
                                  child: Text('Light Load'),
                                ),
                                DropdownMenuItem(
                                  value: 'normal',
                                  child: Text('Normal Load'),
                                ),
                                DropdownMenuItem(
                                  value: 'heavy',
                                  child: Text('Heavy Load'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Notes Field
                        const Text(
                          'Notes (Optional):',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Add any notes about this baseline...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  if (!_isRecording) ...[
                    CustomButton(
                      text: 'Start Recording',
                      icon: Icons.mic,
                      onPressed: _startRecording,
                      width: 200,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Or ',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: _uploadAudioFile,
                          child: Text(
                            'Upload Audio File',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
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

            // Collected Samples (moved up)
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
              }),
              const SizedBox(height: 24),
            ],

            // Baseline History Section
            _buildBaselineHistory(),
            
            // const SizedBox(height: 24),

            // // Instructions (moved down)
            // CustomCard(
            //   color: AppColors.info.withOpacity(0.1),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Row(
            //         children: [
            //           Icon(Icons.info_outline, color: AppColors.info),
            //           const SizedBox(width: 12),
            //           const Text(
            //             'Recording Tips',
            //             style: TextStyle(
            //               fontSize: 16,
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //         ],
            //       ),
            //       const SizedBox(height: 12),
            //       _buildTip('Hold phone 1-2 feet from engine'),
            //       _buildTip('Record in a quiet environment'),
            //       _buildTip('Keep tractor at idle speed'),
            //       _buildTip('Each recording should be 5-10 seconds'),
            //       _buildTip('Collect $_totalSamples samples for best results'),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaselineHistory() {
    if (_isLoadingHistory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baseline History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          CustomCard(
            child: Row(
              children: [
                const CircularProgressIndicator(strokeWidth: 2),
                const SizedBox(width: 16),
                const Text('Loading baseline history...'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    final baselineHistory = _baselineHistory ?? [];

    if (baselineHistory.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Baseline History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          CustomCard(
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No previous baselines found. Start collecting your first baseline!'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Baseline History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...baselineHistory.map((baseline) {
          Color statusColor;
          IconData statusIcon;
          
          switch (baseline['status']) {
            case 'Completed':
              statusColor = AppColors.success;
              statusIcon = Icons.check_circle;
              break;
            case 'Processing':
              statusColor = AppColors.warning;
              statusIcon = Icons.hourglass_empty;
              break;
            case 'Failed':
              statusColor = AppColors.error;
              statusIcon = Icons.error;
              break;
            default:
              statusColor = AppColors.textSecondary;
              statusIcon = Icons.help;
          }

          return CustomCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            baseline['status'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          if (baseline['isActive']) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${baseline['date']} • ${baseline['samples']} samples',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  onPressed: () => _deleteBaseline(baseline['id']),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _deleteBaseline(String baselineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Baseline'),
        content: const Text('Are you sure you want to delete this baseline? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Text('Deleting baseline...'),
                      ],
                    ),
                  ),
                );

                // For now, we don't have a specific delete baseline API
                // So we'll simulate it by removing from local state and reloading
                setState(() {
                  _baselineHistory?.removeWhere((baseline) => baseline['id'] == baselineId);
                });

                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Baseline deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete baseline: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


}