// lib/screens/tractors/add_tractor_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../config/colors.dart';

class AddTractorScreen extends StatefulWidget {
  const AddTractorScreen({Key? key}) : super(key: key);

  @override
  State<AddTractorScreen> createState() => _AddTractorScreenState();
}

class _AddTractorScreenState extends State<AddTractorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tractorIdController = TextEditingController();
  final _modelController = TextEditingController();
  final _engineHoursController = TextEditingController();
  final _purchaseYearController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _tractorIdController.dispose();
    _modelController.dispose();
    _engineHoursController.dispose();
    _purchaseYearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);

    final data = {
      'tractor_id': _tractorIdController.text.trim(),
      'model': _modelController.text.trim(),
      'engine_hours': double.parse(_engineHoursController.text),
      if (_purchaseYearController.text.isNotEmpty)
        'purchase_year': int.parse(_purchaseYearController.text),
      if (_notesController.text.isNotEmpty) 'notes': _notesController.text.trim(),
    };

    final success = await tractorProvider.createTractor(data);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tractor added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tractorProvider.error ?? 'Failed to add tractor'),
          backgroundColor: AppColors.error,
        ),
      );
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

              // Model Field
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Model *',
                  hintText: 'e.g., John Deere 5075E',
                  prefixIcon: const Icon(Icons.precision_manufacturing),
                  helperText: 'Make and model of your tractor',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the tractor model';
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