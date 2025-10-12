// lib/screens/schedule_service_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class ScheduleServiceScreen extends StatefulWidget {
  const ScheduleServiceScreen({super.key});

  @override
  State<ScheduleServiceScreen> createState() => _ScheduleServiceScreenState();
}

class _ScheduleServiceScreenState extends State<ScheduleServiceScreen> {
  DateTime? _selectedDate;
  String? _selectedMechanic;
  final Set<String> _selectedServices = {};

  final List<Map<String, dynamic>> _availableServices = [
    {
      'name': 'Engine Oil Change',
      'cost': 25000,
      'duration': '45 min',
      'priority': 'high'
    },
    {
      'name': 'Air Filter Cleaning',
      'cost': 5000,
      'duration': '20 min',
      'priority': 'medium'
    },
    {
      'name': 'Fuel Filter Replacement',
      'cost': 12000,
      'duration': '30 min',
      'priority': 'high'
    },
    {
      'name': 'Hydraulic Oil Change',
      'cost': 35000,
      'duration': '60 min',
      'priority': 'high'
    },
    {
      'name': 'Belt Inspection',
      'cost': 8000,
      'duration': '20 min',
      'priority': 'medium'
    },
    {
      'name': 'Battery Check',
      'cost': 2000,
      'duration': '15 min',
      'priority': 'low'
    },
  ];

  final List<Map<String, dynamic>> _mechanics = [
    {
      'name': 'John Mugisha',
      'distance': '5 km',
      'rating': 4.8,
      'reviews': 127,
      'phone': '+250 788 123 456',
    },
    {
      'name': 'Peter Nkurunziza',
      'distance': '12 km',
      'rating': 4.6,
      'reviews': 95,
      'phone': '+250 788 234 567',
    },
    {
      'name': 'Emmanuel Habimana',
      'distance': '18 km',
      'rating': 4.9,
      'reviews': 203,
      'phone': '+250 788 345 678',
    },
  ];

  int get totalCost {
    return _selectedServices.fold<int>(0, (sum, serviceName) {
      final service = _availableServices.firstWhere(
        (s) => s['name'] == serviceName,
      );
      return sum + (service['cost'] as int);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Schedule Service'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select Services Section
                  _buildSectionTitle('Select Services'),
                  const SizedBox(height: 12),
                  _buildServicesSection(),
                  const SizedBox(height: 24),

                  // Select Date Section
                  _buildSectionTitle('Select Date'),
                  const SizedBox(height: 12),
                  _buildDateSelector(),
                  const SizedBox(height: 24),

                  // Select Mechanic Section
                  _buildSectionTitle('Select Mechanic'),
                  const SizedBox(height: 12),
                  _buildMechanicsSection(),
                  const SizedBox(height: 24),

                  // Cost Summary
                  _buildCostSummary(),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),

          // Bottom Booking Button
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      children: _availableServices.map((service) {
        final isSelected = _selectedServices.contains(service['name']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedServices.add(service['name']);
                } else {
                  _selectedServices.remove(service['name']);
                }
              });
            },
            title: Text(
              service['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Text('${service['cost']} RWF'),
                const SizedBox(width: 16),
                Text('⏱️ ${service['duration']}'),
                const SizedBox(width: 8),
                _buildPriorityBadge(service['priority']),
              ],
            ),
            activeColor: AppColors.primary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'high':
  color = AppColors.error;
        break;
      case 'medium':
  color = AppColors.warning;
        break;
      default:
  color = AppColors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDate != null
                ? const Color(0xFF667EEA)
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: _selectedDate != null
                  ? const Color(0xFF667EEA)
                  : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDate != null
                        ? DateFormat('EEEE, MMMM dd, yyyy').format(_selectedDate!)
                        : 'Select a date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectedDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (_selectedDate != null)
                    Text(
                      '${_selectedDate!.difference(DateTime.now()).inDays} days from now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicsSection() {
    return Column(
      children: _mechanics.map((mechanic) {
        final isSelected = _selectedMechanic == mechanic['name'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: RadioListTile<String>(
            value: mechanic['name'],
            groupValue: _selectedMechanic,
            onChanged: (value) {
              setState(() {
                _selectedMechanic = value;
              });
            },
            title: Text(
              mechanic['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(mechanic['distance']),
                    const SizedBox(width: 16),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${mechanic['rating']} (${mechanic['reviews']})'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  mechanic['phone'],
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            activeColor: AppColors.primary,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCostSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Services Selected:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                '${_selectedServices.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Cost:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalCost.toString()} RWF',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final canBook = _selectedServices.isNotEmpty &&
        _selectedDate != null &&
        _selectedMechanic != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: canBook ? _confirmBooking : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Text(
            canBook
                ? 'CONFIRM BOOKING - ${totalCost.toString()} RWF'
                : 'SELECT SERVICES, DATE & MECHANIC',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmBooking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Services: ${_selectedServices.length}'),
            Text('Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}'),
            Text('Mechanic: $_selectedMechanic'),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Total: ${totalCost.toString()} RWF',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ Service booked successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}