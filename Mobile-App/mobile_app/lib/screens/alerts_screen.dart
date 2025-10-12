// lib/screens/alerts_screen.dart

import 'package:flutter/material.dart';
import '../models/tractor.dart';
import '../models/maintenance_alert.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _apiService = ApiService();
  List<MaintenanceAlert> _alerts = [];
  bool _isLoading = false;
  String _filterStatus = 'all'; // all, overdue, urgent, due_soon

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

  List<MaintenanceAlert> get filteredAlerts {
    if (_filterStatus == 'all') return _alerts;
    return _alerts.where((a) => a.status == _filterStatus).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'overdue':
        return AppColors.error;
      case 'urgent':
        return AppColors.warning;
      case 'due_soon':
        return AppColors.warning.withOpacity(0.9);
      case 'approaching':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount = _alerts.where((a) => a.status == 'overdue').length;
    final urgentCount = _alerts.where((a) => a.status == 'urgent').length;
    final dueSoonCount = _alerts.where((a) => a.status == 'due_soon').length;
    final totalCost = _alerts.fold<int>(
      0,
      (sum, alert) => sum + alert.estimatedCostRwf,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Maintenance Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Overdue',
                            overdueCount.toString(),
                            AppColors.error,
                          ),
                          _buildSummaryItem(
                            'Urgent',
                            urgentCount.toString(),
                            AppColors.warning,
                          ),
                          _buildSummaryItem(
                            'Due Soon',
                            dueSoonCount.toString(),
                            AppColors.warning.withOpacity(0.9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.attach_money,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Est. Cost: ${totalCost.toString()} RWF',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all', _alerts.length),
                        _buildFilterChip('Overdue', 'overdue', overdueCount),
                        _buildFilterChip('Urgent', 'urgent', urgentCount),
                        _buildFilterChip('Due Soon', 'due_soon', dueSoonCount),
                      ],
                    ),
                  ),
                ),

                // Alerts List
                Expanded(
                  child: filteredAlerts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadAlerts,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredAlerts.length,
                            itemBuilder: (context, index) {
                              return _buildAlertCard(filteredAlerts[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 32,
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
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = value;
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Widget _buildAlertCard(MaintenanceAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(alert.status),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(alert.status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Text(
                  alert.getStatusEmoji(),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.description,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(alert.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          alert.status.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.schedule,
                  'Time Remaining',
                  '${alert.hoursRemaining.toInt()}h or ${alert.daysRemaining} days',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.priority_high,
                  'Priority',
                  alert.priority.toUpperCase(),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.attach_money,
                  'Estimated Cost',
                  '${alert.estimatedCostRwf.toString()} RWF',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Color(0xFF667EEA),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.recommendation,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16).copyWith(top: 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Schedule service action
                      _showScheduleDialog(alert);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Schedule'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // View details action
                      _showDetailsDialog(alert);
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No alerts for this filter',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All maintenance is up to date!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(MaintenanceAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Maintenance'),
        content: Text(
          'Schedule "${alert.description}" for your tractor?\n\n'
          'Estimated cost: ${alert.estimatedCostRwf} RWF',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Service scheduled successfully!'),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(MaintenanceAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.description),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogDetail('Status', alert.status.replaceAll('_', ' ')),
              _buildDialogDetail('Priority', alert.priority.toUpperCase()),
              _buildDialogDetail(
                'Hours Remaining',
                '${alert.hoursRemaining.toInt()}h',
              ),
              _buildDialogDetail('Days Remaining', '${alert.daysRemaining}d'),
              _buildDialogDetail(
                'Cost',
                '${alert.estimatedCostRwf} RWF',
              ),
              const SizedBox(height: 12),
              const Text(
                'Recommendation:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(alert.recommendation),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}