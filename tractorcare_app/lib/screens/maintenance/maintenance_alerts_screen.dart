// lib/screens/maintenance/maintenance_alerts_screen.dart

import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class MaintenanceAlertsScreen extends StatefulWidget {
  final String tractorId;

  const MaintenanceAlertsScreen({
    super.key,
    required this.tractorId,
  });

  @override
  State<MaintenanceAlertsScreen> createState() => _MaintenanceAlertsScreenState();
}

class _MaintenanceAlertsScreenState extends State<MaintenanceAlertsScreen> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    
    try {
      final alerts = await _apiService.getMaintenanceAlerts(widget.tractorId);
      
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alerts: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getTimeUntil(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days remaining';
    } else if (difference.inDays == 0) {
      return 'Due today';
    } else {
      return '${-difference.inDays} days overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
          : _alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No maintenance alerts',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All maintenance tasks are up to date',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (context, index) {
                      final alert = _alerts[index];
                      final priority = alert['priority'] ?? 'medium';
                      final taskName = alert['task_name'] ?? 'Unknown Task';
                      final dueDate = alert['due_date'] != null 
                          ? DateTime.parse(alert['due_date']) 
                          : null;
                      final description = alert['description'] ?? '';
                      final status = alert['status'] ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            // TODO: Navigate to maintenance detail or record maintenance
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(priority).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getPriorityIcon(priority),
                                        color: _getPriorityColor(priority),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            taskName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getPriorityColor(priority).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              priority.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _getPriorityColor(priority),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (dueDate != null)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatDate(alert['due_date']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: dueDate.isBefore(DateTime.now())
                                                  ? AppColors.error
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getTimeUntil(dueDate),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: dueDate.isBefore(DateTime.now())
                                                  ? AppColors.error
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 12),
                                
                                // Status Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'completed'
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.warning.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: status == 'completed'
                                              ? AppColors.success
                                              : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: Mark as completed or schedule maintenance
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Open maintenance screen to record completion'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.build, size: 16),
                                      label: const Text('Record Maintenance'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

