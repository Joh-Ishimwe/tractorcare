// lib/screens/baseline/baseline_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../../providers/audio_provider.dart';
import '../../config/colors.dart';
import '../../services/api_service.dart';

class BaselineCollectionScreen extends StatefulWidget {
  const BaselineCollectionScreen({super.key});

  @override
  State<BaselineCollectionScreen> createState() =>
      _BaselineCollectionScreenState();
}

class _BaselineCollectionScreenState extends State<BaselineCollectionScreen> {
  final int _totalSamples = 5;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  String? _tractorId;
  String? _baselineId;
  bool _isLoading = false;
  double? _tractorHours;
  String? _tractorModel;
  List<Map<String, dynamic>>? _baselineHistory;
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

  bool get isLoading => _isLoading;

  void _startRecording() async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    final success = await audioProvider.startRecording();

    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });

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
        _baselineHistory ??= [];
        _baselineHistory!.insert(0, {
          'filename': 'Recording ${DateTime.now().millisecondsSinceEpoch}.wav',
          'status': 'pending',
          'date': DateTime.now().toString(),
        });
      });
      
      _simulateUpload(0);
    }
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
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBaselineHistory() async {
    if (_tractorId == null) return;
    
    try {
      final apiService = ApiService();
      final baselines = await apiService.getBaselineHistory(_tractorId!);
      
      List<Map<String, dynamic>> history = [];
      for (var baseline in baselines) {
        history.add({
          'id': baseline['id']?.toString() ?? '',
          'date': _formatDate(baseline['created_at']),
          'status': _mapStatus(baseline['status']),
          'filename': 'Baseline ${baseline['id']}',
        });
      }
      
      setState(() {
        _baselineHistory = history;
      });
    } catch (e) {
      setState(() {
        _baselineHistory = [];
      });
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
        return 'uploaded';
      case 'processing':
        return 'pending';
      case 'failed':
        return 'failed';
      default:
        return 'pending';
    }
  }

  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Green Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.successGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Record Engine Sound',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            
            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Recording Interface
                    _buildRecordingInterface(),
                    
                    const SizedBox(height: 24),
                    
                    // Upload Options
                    _buildUploadOptions(),
                    
                    const SizedBox(height: 32),
                    
                    // Recent Uploads
                    _buildRecentUploads(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingInterface() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.successGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Microphone Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              size: 40,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Timer Display
          Text(
            _formatTime(_recordingDuration),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Status Text
          Text(
            _isRecording ? 'Recording...' : 'Ready to Record',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOptions() {
    return Column(
      children: [
        // Record Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isRecording ? _stopRecording : _startRecording,
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(_isRecording ? 'STOP RECORDING' : 'START RECORDING'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Upload from Files Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _pickAudioFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('UPLOAD FROM FILES'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.success,
              side: const BorderSide(color: AppColors.success),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentUploads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Uploads',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_baselineHistory == null || _baselineHistory!.isEmpty) 
          _buildEmptyUploads()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _baselineHistory!.length,
            itemBuilder: (context, index) {
              final upload = _baselineHistory![index];
              return _buildUploadItem(upload, index);
            },
          ),
      ],
    );
  }

  Widget _buildEmptyUploads() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No uploads yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording to create your first baseline',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadItem(Map<String, dynamic> upload, int index) {
    final isUploaded = upload['status'] == 'uploaded';
    final isPending = upload['status'] == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUploaded 
                ? AppColors.success.withOpacity(0.1)
                : isPending 
                  ? AppColors.warning.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isUploaded 
                ? Icons.check_circle
                : isPending 
                  ? Icons.schedule
                  : Icons.error,
              color: isUploaded 
                ? AppColors.success
                : isPending 
                  ? AppColors.warning
                  : AppColors.error,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Upload Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload['filename'] ?? 'Recording ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  upload['date'] ?? 'Just now',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Delete Button
          IconButton(
            onPressed: () => _deleteUpload(index),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _deleteUpload(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Upload'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _baselineHistory?.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.first;
        // Add to recent uploads
        setState(() {
          _baselineHistory ??= [];
          _baselineHistory!.insert(0, {
            'filename': file.name,
            'status': 'pending',
            'date': DateTime.now().toString(),
          });
        });
        
        // Simulate upload process
        _simulateUpload(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _simulateUpload(int index) {
    // Simulate upload delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _baselineHistory != null && index < _baselineHistory!.length) {
        setState(() {
          _baselineHistory![index]['status'] = 'uploaded';
        });
      }
    });
  }
}