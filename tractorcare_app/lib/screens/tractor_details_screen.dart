// lib/screens/tractor_details_screen.dart

import 'package:flutter/material.dart';
import '../theme.dart';

class TractorDetailsScreen extends StatelessWidget {
  const TractorDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tractors'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTractorDialog(context),
            tooltip: 'Add Tractor',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTractorCard(
            context,
            model: 'John Deere 5075E',
            hours: 245.5,
            health: 'Healthy',
            healthColor: AppColors.success,
            lastService: '15 days ago',
          ),
          const SizedBox(height: 12),
          _buildTractorCard(
            context,
            model: 'Mahindra 575 DI',
            hours: 892.0,
            health: 'Warning',
            healthColor: AppColors.warning,
            lastService: '45 days ago',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTractorDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Tractor'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildTractorCard(
    BuildContext context, {
    required String model,
    required double hours,
    required String health,
    required Color healthColor,
    required String lastService,
  }) {
    return Card(
      child: InkWell(
        onTap: () => _showTractorDetails(context, model),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: healthColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            health,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: healthColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.schedule,
                      'Engine Hours',
                      '${hours.toStringAsFixed(1)}h',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.build,
                      'Last Service',
                      lastService,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showTractorDetails(BuildContext context, String model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                model,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailSection('Specifications', [
                {'label': 'Model', 'value': model},
                {'label': 'Engine Hours', 'value': '245.5 hours'},
                {'label': 'Usage', 'value': 'Moderate'},
                {'label': 'Purchase Date', 'value': 'Jan 15, 2023'},
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Health Status', [
                {'label': 'Overall', 'value': 'Healthy'},
                {'label': 'Engine', 'value': 'Good'},
                {'label': 'Hydraulics', 'value': 'Good'},
                {'label': 'Electrical', 'value': 'Good'},
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit feature coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Map<String, String>> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['label']!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        item['value']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showAddTractorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tractor'),
        content: const Text(
          'Full tractor registration form coming soon!\n\n'
          'You will be able to add:\n'
          '• Tractor model\n'
          '• Engine hours\n'
          '• Purchase date\n'
          '• Usage intensity',
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
}
