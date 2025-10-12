// lib/screens/tractor_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tractor.dart';
import 'schedule_service_screen.dart';

class TractorDetailsScreen extends StatefulWidget {
  const TractorDetailsScreen({super.key});

  @override
  State<TractorDetailsScreen> createState() => _TractorDetailsScreenState();
}

class _TractorDetailsScreenState extends State<TractorDetailsScreen> {
  final Tractor _tractor = Tractor(
    tractorId: 'TR001',
    model: 'MF_240',
    engineHours: 1450,
    usageIntensity: 'moderate',
    purchaseDate: DateTime(2023, 1, 15),
    healthStatus: 'warning',
  );

  // Mock maintenance history
  final List<Map<String, dynamic>> _maintenanceHistory = [
    {
      'date': DateTime(2024, 9, 15),
      'task': 'Engine Oil Change',
      'cost': 25000,
      'notes': 'Regular service performed',
    },
    {
      'date': DateTime(2024, 8, 1),
      'task': 'Air Filter Cleaning',
      'cost': 5000,
      'notes': 'Filter cleaned and inspected',
    },
    {
      'date': DateTime(2024, 6, 10),
      'task': 'Hydraulic Oil Change',
      'cost': 35000,
      'notes': 'Full hydraulic system service',
    },
    {
      'date': DateTime(2024, 4, 5),
      'task': 'Belt Replacement',
      'cost': 8000,
      'notes': 'Alternator belt replaced',
    },
  ];

  Color _getHealthColor(String status) {
    switch (status) {
      case 'healthy':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Tractor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tractor Header Card
            _buildHeaderCard(),

            // Stats Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Engine Hours',
                      '${_tractor.engineHours.toInt()}h',
                      Icons.speed,
                      const Color(0xFF667EEA),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Usage',
                      _tractor.usageIntensity.toUpperCase(),
                      Icons.trending_up,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'Schedule Service',
                          Icons.calendar_today,
                          const Color(0xFF667EEA),
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScheduleServiceScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          'Contact Mechanic',
                          Icons.phone,
                          Colors.green,
                          _callMechanic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Maintenance History
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Service History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // View all history
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMaintenanceTimeline(),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final daysSincePurchase = DateTime.now().difference(_tractor.purchaseDate).inDays;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getHealthColor(_tractor.healthStatus),
            _getHealthColor(_tractor.healthStatus).withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tractor Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.agriculture,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Model and ID
          Text(
            _tractor.model.replaceAll('_', ' '),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'ID: ${_tractor.tractorId}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_tractor.healthStatus.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Purchase Info
          Text(
            'Purchased: ${DateFormat('MMM dd, yyyy').format(_tractor.purchaseDate)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          Text(
            '$daysSincePurchase days in service',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceTimeline() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _maintenanceHistory.length,
      itemBuilder: (context, index) {
        final item = _maintenanceHistory[index];
        final isLast = index == _maintenanceHistory.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['task'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(item['date']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${item['cost']} RWF',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog() {
    final engineHoursController = TextEditingController(
      text: _tractor.engineHours.toString(),
    );
    String selectedIntensity = _tractor.usageIntensity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Tractor Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: engineHoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Engine Hours',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedIntensity,
              decoration: const InputDecoration(
                labelText: 'Usage Intensity',
                border: OutlineInputBorder(),
              ),
              items: ['light', 'moderate', 'heavy', 'extreme']
                  .map((intensity) => DropdownMenuItem(
                        value: intensity,
                        child: Text(intensity.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedIntensity = value;
                }
              },
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
              // Update tractor info
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tractor info updated successfully!'),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _callMechanic() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Mechanic'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('John Mugisha - Certified Mechanic'),
            SizedBox(height: 8),
            Text('Phone: +250 788 123 456'),
            Text('Location: Kayonza District'),
            Text('Rating: ⭐⭐⭐⭐⭐ (4.8/5)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // In real app: launch phone dialer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening phone dialer...'),
                ),
              );
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call Now'),
          ),
        ],
      ),
    );
  }
}