// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/tractor.dart';
import '../models/maintenance_alert.dart';
import '../services/api_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<MaintenanceAlert> _alerts = [];
  bool _isLoading = false;

  // Default tractor for demo
  final Tractor _defaultTractor = Tractor(
    tractorId: 'TR001',
    model: 'MF_240',
    engineHours: 1450,
    usageIntensity: 'moderate',
    purchaseDate: DateTime(2023, 1, 15),
    healthStatus: 'warning',
  );

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await _apiService.getRuleBasedPredictions(_defaultTractor);
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading alerts: $e')),
        );
      }
    }
  }

  Color _getHealthColor(String status) {
    switch (status) {
      case 'healthy':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'critical':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String _getHealthEmoji(String status) {
    switch (status) {
      case 'healthy':
        return '🟢';
      case 'warning':
        return '🟡';
      case 'critical':
        return '🔴';
      default:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _alerts.where((a) => a.status == 'overdue').length;
    final urgentCount = _alerts.where((a) => a.status == 'urgent').length;
    final totalCost = _alerts.fold<int>(
      0,
      (sum, alert) => sum + alert.estimatedCostRwf,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('TractorCare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health Status Card
                    _buildHealthStatusCard(),
                    const SizedBox(height: 20),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                    const SizedBox(height: 20),

                    // Summary Cards
                    const Text(
                      'Maintenance Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Alerts',
                            _alerts.length.toString(),
                            Icons.warning,
                            AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Overdue',
                            overdueCount.toString(),
                            Icons.error,
                            AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Urgent',
                            urgentCount.toString(),
                            Icons.priority_high,
                            AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Cost',
                            '${(totalCost / 1000).toStringAsFixed(0)}K RWF',
                            Icons.attach_money,
                            AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Next Maintenance
                    if (_alerts.isNotEmpty) ...[
                      const Text(
                        'Next Maintenance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNextMaintenanceCard(_alerts.first),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHealthStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getHealthColor(_defaultTractor.healthStatus),
            _getHealthColor(_defaultTractor.healthStatus).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getHealthColor(_defaultTractor.healthStatus).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _defaultTractor.model.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _defaultTractor.tractorId,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                _getHealthEmoji(_defaultTractor.healthStatus),
                style: const TextStyle(fontSize: 48),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Engine Hours',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_defaultTractor.engineHours.toInt()}h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _defaultTractor.healthStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Record Sound',
            Icons.mic,
            Colors.purple,
            () {
              // Navigate to record screen
              DefaultTabController.of(context).animateTo(1);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'View Alerts',
            Icons.notifications,
            Colors.orange,
            () {
              // Navigate to alerts screen
              DefaultTabController.of(context).animateTo(2);
            },
          ),
        ),
      ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMaintenanceCard(MaintenanceAlert alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
    color: alert.status == 'overdue' ? AppColors.error : AppColors.warning,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(alert.getStatusEmoji(), style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${alert.hoursRemaining.toInt()}h or ${alert.daysRemaining}d remaining',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${alert.estimatedCostRwf.toString()} RWF',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}