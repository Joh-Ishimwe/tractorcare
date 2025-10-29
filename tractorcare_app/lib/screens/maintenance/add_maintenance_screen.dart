// lib/screens/maintenance/add_maintenance_screen.dart

import 'package:flutter/material.dart';
import '../../models/maintenance.dart';
import '../../services/api_service.dart';
import '../../config/colors.dart';

class AddMaintenanceScreen extends StatefulWidget {
  const AddMaintenanceScreen({Key? key}) : super(key: key);

  @override
  State<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends State<AddMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  
  String? _tractorId;
  MaintenanceType _selectedType = MaintenanceType.oilChange;
  final _customTypeController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  final _dueAtHoursController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tractorId == null) {
      _tractorId = ModalRoute.of(context)!.settings.arguments as String?;
    }
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _dueAtHoursController.dispose();
    _estimatedCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'type': _selectedType == MaintenanceType.other
          ? 'other'
          : _getMaintenanceTypeString(_selectedType),
      if (_selectedType == MaintenanceType.other)
        'custom_type': _customTypeController.text.trim(),
      'due_date': _dueDate.toIso8601String(),
      if (_dueAtHoursController.text.isNotEmpty)
        'due_at_hours': double.parse(_dueAtHoursController.text),
      if (_estimatedCostController.text.isNotEmpty)
        'estimated_cost': double.parse(_estimatedCostController.text),
      if (_notesController.text.isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    try {
      data['tractor_id'] = _tractorId!;
      await _api.createMaintenance(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maintenance added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _getMaintenanceTypeString(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.oilChange:
        return 'oil_change';
      case MaintenanceType.filterReplacement:
        return 'filter_replacement';
      case MaintenanceType.inspection:
        return 'inspection';
      case MaintenanceType.repair:
        return 'repair';
      case MaintenanceType.service:
        return 'service';
      case MaintenanceType.other:
        return 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Maintenance'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.build_circle,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Schedule Maintenance',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Keep your tractor in top condition',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Maintenance Type
              const Text(
                'Maintenance Type *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MaintenanceType.values.map((type) {
                  return ChoiceChip(
                    label: Text(_getMaintenanceTypeName(type)),
                    selected: _selectedType == type,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedType = type);
                      }
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _selectedType == type
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Custom Type (if Other selected)
              if (_selectedType == MaintenanceType.other)
                TextFormField(
                  controller: _customTypeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Custom Type *',
                    hintText: 'e.g., Tire Rotation',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  validator: (value) {
                    if (_selectedType == MaintenanceType.other &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter a custom type';
                    }
                    return null;
                  },
                ),

              if (_selectedType == MaintenanceType.other)
                const SizedBox(height: 16),

              // Due Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Due at Engine Hours (Optional)
              TextFormField(
                controller: _dueAtHoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Due at Engine Hours (Optional)',
                  hintText: 'e.g., 2000',
                  prefixIcon: Icon(Icons.access_time),
                  helperText: 'Schedule based on engine hours',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final hours = double.tryParse(value);
                    if (hours == null || hours < 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Estimated Cost (Optional)
              TextFormField(
                controller: _estimatedCostController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Estimated Cost (Optional)',
                  hintText: 'e.g., 150.00',
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Estimated cost in USD',
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final cost = double.tryParse(value);
                    if (cost == null || cost < 0) {
                      return 'Please enter a valid amount';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Notes (Optional)
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Add any additional details...',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
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
                        'You will receive notifications when maintenance is due',
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
                          'SCHEDULE MAINTENANCE',
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

  String _getMaintenanceTypeName(MaintenanceType type) {
    switch (type) {
      case MaintenanceType.oilChange:
        return 'Oil Change';
      case MaintenanceType.filterReplacement:
        return 'Filter Replacement';
      case MaintenanceType.inspection:
        return 'Inspection';
      case MaintenanceType.repair:
        return 'Repair';
      case MaintenanceType.service:
        return 'Service';
      case MaintenanceType.other:
        return 'Other';
    }
  }
}