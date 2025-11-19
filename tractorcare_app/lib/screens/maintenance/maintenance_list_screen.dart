// lib/screens/maintenance/maintenance_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../models/tractor.dart';
import '../../models/maintenance.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';

class MaintenanceListScreen extends StatefulWidget {
  final String? tractorId; // Optional tractor ID to filter by
  
  const MaintenanceListScreen({super.key, this.tractorId});

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  
  String? _selectedTractorId;
  List<Maintenance> _upcomingMaintenance = [];
  List<Maintenance> _completedMaintenance = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer data loading to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    await tractorProvider.fetchTractors();
    
    // If a tractor ID was passed as argument, use it; otherwise use first tractor
    if (mounted) {
      setState(() {
        if (widget.tractorId != null) {
          // Use the tractor ID passed as argument
          _selectedTractorId = widget.tractorId;
        } else if (tractorProvider.tractors.isNotEmpty && _selectedTractorId == null) {
          // Fall back to first tractor if no ID provided
          _selectedTractorId = tractorProvider.tractors.first.tractorId;
        }
      });
      
      if (_selectedTractorId != null) {
        await _loadMaintenance();
      }
    }
  }

  Future<void> _loadMaintenance() async {
    if (_selectedTractorId == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Fetch upcoming maintenance alerts (not records)
      final upcomingAlertsData = await _api.getMaintenanceAlerts(_selectedTractorId!);
      
      // Convert alerts to Maintenance objects for upcoming tasks
      final upcoming = upcomingAlertsData
          .where((alert) => alert['status'] != 'completed')
          .map((alert) => _convertAlertToMaintenance(alert))
          .toList();
      
      // Fetch completed maintenance records
      final completed = await _api.getMaintenance(
        _selectedTractorId!,
        completed: true,
      );

      if (mounted) {
        setState(() {
          _upcomingMaintenance = upcoming;
          _completedMaintenance = completed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading maintenance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Convert maintenance alert to Maintenance object
  Maintenance _convertAlertToMaintenance(Map<String, dynamic> alert) {
    return Maintenance(
      id: alert['id'] ?? '',
      tractorId: alert['tractor_id'] ?? '',
      userId: 'system', // Default user for alerts
      type: _mapAlertTypeToMaintenanceType(alert['alert_type']),
      customType: alert['task_name']?.replaceAll('_', ' ')?.toUpperCase(),
      triggerType: _mapTriggerTypeFromAlert(alert['trigger_type']),
      dueDate: DateTime.tryParse(alert['due_date'] ?? '') ?? DateTime.now(),
      status: _mapAlertStatusToMaintenanceStatus(alert['status']),
      estimatedCost: null,
      notes: '${alert['description'] ?? ''}\n\nSource: ${alert['source'] ?? ''}\n${alert['cost_note'] ?? ''}',
      createdAt: DateTime.tryParse(alert['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  MaintenanceType _mapAlertTypeToMaintenanceType(String? alertType) {
    switch (alertType) {
      case 'routine_overdue':
      case 'routine_scheduled':
        return MaintenanceType.service;
      case 'audio_anomaly':
        return MaintenanceType.repair;
      default:
        return MaintenanceType.other;
    }
  }

  MaintenanceStatus _mapAlertStatusToMaintenanceStatus(String? status) {
    switch (status) {
      case 'overdue':
        return MaintenanceStatus.overdue;
      case 'scheduled':
        return MaintenanceStatus.upcoming;
      case 'completed':
        return MaintenanceStatus.completed;
      default:
        return MaintenanceStatus.upcoming;
    }
  }

  MaintenanceTriggerType _mapTriggerTypeFromAlert(String? triggerType) {
    switch (triggerType?.toLowerCase()) {
      case 'abnormal_sound':
        return MaintenanceTriggerType.abnormalSound;
      case 'usage_interval':
        return MaintenanceTriggerType.usageInterval;
      case 'manual':
      default:
        return MaintenanceTriggerType.manual;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Maintenance'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Upcoming'),
                  if (_upcomingMaintenance.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _upcomingMaintenance.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Completed'),
                  if (_completedMaintenance.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _completedMaintenance.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tractor Selector
          Consumer<TractorProvider>(
            builder: (context, provider, child) {
              if (provider.tractors.isEmpty) {
                return Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'No tractors found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/add-tractor');
                        },
                        child: const Text('Add Tractor'),
                      ),
                    ],
                  ),
                );
              }

              // If a specific tractor ID was passed, show it as read-only; otherwise show dropdown
              if (widget.tractorId != null) {
                // Show selected tractor as read-only when filtered by specific tractor
                final selectedTractor = provider.tractors.firstWhere(
                  (t) => t.tractorId == widget.tractorId,
                  orElse: () => provider.tractors.first,
                );
                return Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(selectedTractor.statusIcon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selectedTractor.tractorId} - ${selectedTractor.model}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.lock, size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                );
              }
              
              return Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTractorId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: provider.tractors.map((Tractor tractor) {
                      return DropdownMenuItem<String>(
                        value: tractor.tractorId,
                        child: Row(
                          children: [
                            Text(tractor.statusIcon),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${tractor.tractorId} - ${tractor.model}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedTractorId = value);
                      _loadMaintenance();
                    },
                  ),
                ),
              );
            },
          ),

          // Tab View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMaintenanceList(_upcomingMaintenance, false),
                      _buildMaintenanceList(_completedMaintenance, true),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedTractorId == null
            ? null
            : () {
                Navigator.pushNamed(
                  context,
                  '/add-maintenance',
                  arguments: _selectedTractorId,
                ).then((_) => _loadMaintenance());
              },
        icon: const Icon(Icons.add),
        label: const Text('Add Maintenance'),
        backgroundColor: _selectedTractorId == null
            ? AppColors.textDisabled
            : AppColors.primary,
      ),
    );
  }

  Widget _buildMaintenanceList(List<Maintenance> items, bool isCompleted) {
    if (items.isEmpty) {
      return _buildEmptyState(isCompleted);
    }

    return RefreshIndicator(
      onRefresh: _loadMaintenance,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final maintenance = items[index];
          return _buildMaintenanceCard(maintenance, isCompleted);
        },
      ),
    );
  }

  Widget _buildMaintenanceCard(Maintenance maintenance, bool isCompleted) {
    final statusColor = AppColors.getMaintenanceStatusColor(maintenance.status.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/maintenance-detail',
            arguments: maintenance,
          ).then((_) => _loadMaintenance());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      maintenance.typeIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance.typeString,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          maintenance.formattedDueDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      maintenance.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        maintenance.isOverdue
                            ? Icons.error
                            : Icons.schedule,
                        size: 16,
                        color: maintenance.isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        maintenance.timeUntilDue,
                        style: TextStyle(
                          fontSize: 14,
                          color: maintenance.isOverdue
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: maintenance.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (maintenance.notes != null && maintenance.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  maintenance.notes!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Add Mark Complete button for non-completed maintenance
              if (!isCompleted) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _markMaintenanceComplete(maintenance),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_outline : Icons.event_note,
              size: 80,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted
                  ? 'No Completed Maintenance'
                  : 'No Upcoming Maintenance',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted
                  ? 'Completed maintenance will appear here'
                  : 'Add maintenance schedules to track them',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _selectedTractorId == null
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/add-maintenance',
                          arguments: _selectedTractorId,
                        ).then((_) => _loadMaintenance());
                      },
                icon: const Icon(Icons.add),
                label: const Text('Add Maintenance'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markMaintenanceComplete(Maintenance maintenance) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Maintenance'),
          content: Text(
            'Mark "${maintenance.typeString}" as completed?\n\nThis will record the task as finished and move it to completed maintenance history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Complete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Recording maintenance...'),
            ],
          ),
        ),
      );

      // Record the completed maintenance
      final maintenanceData = {
        'tractor_id': maintenance.tractorId,
        'task_name': maintenance.customType ?? maintenance.typeString,
        'description': maintenance.notes ?? 'Completed maintenance task',
        'completion_date': DateTime.now().toIso8601String(),
        'completion_hours': maintenance.dueAtHours ?? 0.0,
        'actual_time_minutes': 60, // Default 1 hour
        'notes': 'Completed via mobile app',
        'performed_by': 'Mobile App User',
      };

      final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
      
      if (offlineSyncService.isOnline) {
        try {
          await _api.createMaintenance(maintenanceData);
          
          // Close loading dialog
          if (mounted) Navigator.of(context).pop();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${maintenance.typeString} marked as complete!'),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          // Refresh the data to reflect the completion
          await _loadMaintenance();
        } catch (e) {
          // Close loading dialog if open
          if (mounted) Navigator.of(context).pop();
          
          // If online but request failed, it will be queued by createMaintenance
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Queued for sync: ${maintenance.typeString} will be marked complete when connection improves.'),
                  ],
                ),
                backgroundColor: AppColors.warning,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          
          // Refresh to show pending status
          await _loadMaintenance();
        }
      } else {
        // Offline: createMaintenance will queue it automatically
        await _api.createMaintenance(maintenanceData);
        
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();
        
        // Show offline message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.cloud_upload, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Offline: ${maintenance.typeString} queued and will be marked complete when online.'),
                ],
              ),
              backgroundColor: AppColors.info,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Refresh the data
        await _loadMaintenance();
      }
      
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.of(context).pop();
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to complete maintenance: ${e.toString()}'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      AppConfig.logError('Failed to complete maintenance', e);
    }
  }
}