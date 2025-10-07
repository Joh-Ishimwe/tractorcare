import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'tractor_detail_screen.dart';

class TractorListScreen extends StatelessWidget {
  const TractorListScreen({Key? key}) : super(key: key);

  // Mock data
  final List<Map<String, dynamic>> tractors = const [
    {
      'tractor_id': 'TR001',
      'model': 'Massey Ferguson 240',
      'engine_hours': 1200.5,
      'status': 'available',
      'health': 'good',
    },
    {
      'tractor_id': 'TR002',
      'model': 'Massey Ferguson 375',
      'engine_hours': 2450.0,
      'status': 'in_use',
      'health': 'warning',
    },
    {
      'tractor_id': 'TR003',
      'model': 'John Deere 5075E',
      'engine_hours': 850.0,
      'status': 'maintenance',
      'health': 'critical',
    },
    {
      'tractor_id': 'TR004',
      'model': 'New Holland TD5',
      'engine_hours': 3200.0,
      'status': 'available',
      'health': 'good',
    },
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppTheme.successGreen;
      case 'in_use':
        return AppTheme.accentOrange;
      case 'maintenance':
        return AppTheme.criticalRed;
      default:
        return AppTheme.neutralGray;
    }
  }

  Color _getHealthColor(String health) {
    switch (health) {
      case 'good':
        return AppTheme.successGreen;
      case 'warning':
        return AppTheme.warningYellow;
      case 'critical':
        return AppTheme.criticalRed;
      default:
        return AppTheme.neutralGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tractors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.lightGray,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total', '15', Icons.agriculture),
                _buildStatCard('Available', '8', Icons.check_circle),
                _buildStatCard('In Use', '6', Icons.access_time),
                _buildStatCard('Maintenance', '1', Icons.build),
              ],
            ),
          ),

          // Tractor List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tractors.length,
              itemBuilder: (context, index) {
                final tractor = tractors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: _getStatusColor(tractor['status']),
                      child: const Icon(
                        Icons.agriculture,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      tractor['tractor_id'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(tractor['model']),
                        const SizedBox(height: 4),
                        Text(
                          '${tractor['engine_hours']} hours',
                          style: TextStyle(color: AppTheme.neutralGray),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getHealthColor(tractor['health'])
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tractor['health'].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getHealthColor(tractor['health']),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TractorDetailScreen(tractor: tractor),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.neutralGray,
          ),
        ),
      ],
    );
  }
}