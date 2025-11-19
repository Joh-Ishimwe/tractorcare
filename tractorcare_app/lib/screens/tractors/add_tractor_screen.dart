// lib/screens/tractors/add_tractor_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/colors.dart';
import '../../widgets/feedback_helper.dart';

class AddTractorScreen extends StatefulWidget {
  const AddTractorScreen({super.key});

  @override
  State<AddTractorScreen> createState() => _AddTractorScreenState();
}

class _AddTractorScreenState extends State<AddTractorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tractorIdController = TextEditingController();
  final _engineHoursController = TextEditingController();
  final _purchaseYearController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedModel; // Selected tractor model
  bool _isLoading = false;
  
  // Available tractor models
  static const List<String> _availableModels = ['MF_240', 'MF_375'];

  @override
  void dispose() {
    _tractorIdController.dispose();
    _engineHoursController.dispose();
    _purchaseYearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Check authentication first
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first to add a tractor'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);

    // Validate model is selected
    if (_selectedModel == null) {
      setState(() => _isLoading = false);
      FeedbackHelper.showError(context, 'Please select a tractor model');
      return;
    }

    final model = _selectedModel!;

    // Backend expects purchase_date (datetime). If user provided only year, use Jan 1 of that year; otherwise use today.
    DateTime purchaseDate;
    if (_purchaseYearController.text.isNotEmpty) {
      final year = int.tryParse(_purchaseYearController.text)!;
      purchaseDate = DateTime(year, 1, 1);
    } else {
      purchaseDate = DateTime.now();
    }

    // Clean tractor ID - remove any non-alphanumeric characters except dashes/underscores
    final tractorId = _tractorIdController.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    
    // Validate tractor ID length
    if (tractorId.length < 3 || tractorId.length > 20) {
      setState(() => _isLoading = false);
      FeedbackHelper.showError(context, 'Tractor ID must be between 3 and 20 characters');
      return;
    }
    
    final data = {
      'tractor_id': tractorId,
      'model': model,
      'engine_hours': double.parse(_engineHoursController.text),
      'purchase_date': purchaseDate.toIso8601String(),
    };

    final success = await tractorProvider.createTractor(data);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      FeedbackHelper.showSuccess(context, 'Tractor added successfully!');
      Navigator.pop(context);
    } else {
      final errorMessage = tractorProvider.error ?? 'Failed to add tractor';
      
      // Check if it's an authentication error
      if (errorMessage.contains('login again') || errorMessage.contains('Authentication')) {
        final shouldLogout = await FeedbackHelper.showConfirmation(
          context,
          title: 'Session Expired',
          message: 'Your session has expired. Please login again to continue.',
          confirmText: 'Login',
          cancelText: 'Cancel',
        );
        if (shouldLogout && mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        FeedbackHelper.showError(context, FeedbackHelper.formatErrorMessage(errorMessage));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Tractor'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.agriculture,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add New Tractor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fill in the details below to register your tractor',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Tractor ID Field
              TextFormField(
                controller: _tractorIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Tractor ID *',
                  hintText: 'e.g., TR-001',
                  prefixIcon: const Icon(Icons.tag),
                  helperText: 'Unique identifier for your tractor',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a tractor ID';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Model Dropdown Field
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: InputDecoration(
                  labelText: 'Model *',
                  hintText: 'Select tractor model',
                  prefixIcon: const Icon(Icons.precision_manufacturing),
                  helperText: 'Choose between MF 240 or MF 375',
                ),
                items: _availableModels.map((String model) {
                  // Display format: "MF 240" instead of "MF_240"
                  final displayName = model.replaceAll('_', ' ');
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedModel = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a tractor model';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Engine Hours Field
              TextFormField(
                controller: _engineHoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Engine Hours *',
                  hintText: 'e.g., 1250.5',
                  prefixIcon: const Icon(Icons.access_time),
                  helperText: 'Current engine hours',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter engine hours';
                  }
                  final hours = double.tryParse(value);
                  if (hours == null || hours < 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Purchase Year Field (Optional)
              TextFormField(
                controller: _purchaseYearController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Purchase Year (Optional)',
                  hintText: 'e.g., 2020',
                  prefixIcon: const Icon(Icons.calendar_today),
                  helperText: 'Year you purchased the tractor',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final year = int.tryParse(value);
                    if (year == null) {
                      return 'Please enter a valid year';
                    }
                    final currentYear = DateTime.now().year;
                    if (year < 1900 || year > currentYear) {
                      return 'Year must be between 1900 and $currentYear';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Notes Field (Optional)
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional information...',
                  prefixIcon: const Icon(Icons.notes),
                  alignLabelWithHint: true,
                  helperText: 'Special features, modifications, etc.',
                ),
              ),

              const SizedBox(height: 32),

              // Info Box
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Fields marked with * are required',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'ADD TRACTOR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}