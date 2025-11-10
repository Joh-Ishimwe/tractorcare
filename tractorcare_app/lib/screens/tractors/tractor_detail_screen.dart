// lib/screens/tractors/tractor_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../providers/audio_provider.dart';
import '../../models/tractor.dart';
import '../../models/tractor_summary.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/offline_sync_service.dart';
import 'dart:convert';


class TractorDetailScreen extends StatefulWidget {
  const TractorDetailScreen({super.key});

  @override
  State<TractorDetailScreen> createState() => _TractorDetailScreenState();
}

class _TractorDetailScreenState extends State<TractorDetailScreen> {
  String? _tractorId;
  bool _isLoading = true;
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  TractorSummary? _tractorSummary;
  List<dynamic>? _maintenanceAlerts;
  bool _hasBaseline = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tractorId == null) {
      _tractorId = ModalRoute.of(context)!.settings.arguments as String;
      
      AppConfig.log('🔍 Tractor Detail Screen: Received ID: $_tractorId');
      AppConfig.log('   - Length: ${_tractorId!.length}');
      AppConfig.log('   - Is ObjectID format (24 hex chars): ${_tractorId!.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_tractorId!)}');
      AppConfig.log('   - Is TractorID format (starts with T): ${_tractorId!.startsWith('T')}');
      
      if (_tractorId!.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_tractorId!)) {
        AppConfig.logError('⚠️ WARNING: Received ObjectID format, this will cause 404 errors!');
        AppConfig.logError('   Expected format: T007, T001, etc.');
      }
      
      // Defer loading until after first frame to avoid notifying listeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadData();
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
    await tractorProvider.getTractor(_tractorId!);
    
    // After loading tractor, use the actual tractorId from the loaded data for API calls
    final loadedTractor = tractorProvider.selectedTractor;
    if (loadedTractor != null) {
      final actualTractorId = loadedTractor.tractorId;
      AppConfig.log('🔧 Using actual tractor ID for API calls: $actualTractorId (was: $_tractorId)');
      
      await audioProvider.fetchPredictions(actualTractorId, limit: 5);
      
      // Update _tractorId to use the actual tractor ID for subsequent calls
      _tractorId = actualTractorId;
    }
    
    // Load maintenance summary and alerts
    await _loadMaintenanceData();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadMaintenanceData() async {
    if (_tractorId == null) return;
    
    try {
      AppConfig.log('🔧 Loading maintenance data for tractor: $_tractorId');
      
      if (_offlineSyncService.isOnline) {
        await _loadOnlineMaintenanceData();
      } else {
        await _loadCachedMaintenanceData();
      }
      
    } catch (e) {
      AppConfig.logError('❌ General maintenance data error', e);
      // Fall back to cached data when there's an error
      await _loadCachedMaintenanceData();
    }
  }

  Future<void> _loadOnlineMaintenanceData() async {
    try {
      // Load tractor summary for maintenance information
      try {
        AppConfig.log('📡 Attempting to load tractor summary for: $_tractorId');
        _tractorSummary = await _apiService.getTractorSummary(_tractorId!);
        AppConfig.log('✅ Tractor summary loaded: ${_tractorSummary?.alerts.length} alerts');
        
        // Cache the summary
        await _storageService.setString('tractor_summary_$_tractorId', jsonEncode(_tractorSummary!.toJson()));
      } catch (e) {
        AppConfig.logError('❌ Failed to load tractor summary', e);
        AppConfig.logError('❌ Summary error details: ${e.toString()}');
        // Try to load from cache
        await _loadCachedTractorSummary();
      }
      
      // Load maintenance alerts  
      try {
        _maintenanceAlerts = await _apiService.getMaintenanceAlerts(_tractorId!);
        AppConfig.log('✅ Maintenance alerts loaded: ${_maintenanceAlerts?.length} alerts');
        
        // Cache the alerts
        await _storageService.setString('maintenance_alerts_$_tractorId', jsonEncode(_maintenanceAlerts));
      } catch (e) {
        AppConfig.logError('❌ Failed to load maintenance alerts', e);
        // Try to load from cache
        await _loadCachedMaintenanceAlerts();
      }

      // Check baseline status
      await _checkBaselineStatus();
    } catch (e) {
      AppConfig.logError('❌ Error loading online maintenance data', e);
      await _loadCachedMaintenanceData();
    }
  }

  Future<void> _loadCachedMaintenanceData() async {
    AppConfig.log('📱 Loading cached maintenance data for: $_tractorId');
    
    await _loadCachedTractorSummary();
    await _loadCachedMaintenanceAlerts();
    await _loadCachedBaselineStatus();
  }

  Future<void> _loadCachedTractorSummary() async {
    try {
      final cachedSummary = await _storageService.getString('tractor_summary_$_tractorId');
      if (cachedSummary != null) {
        final summaryData = jsonDecode(cachedSummary);
        _tractorSummary = TractorSummary.fromJson(summaryData);
        AppConfig.log('✅ Loaded cached tractor summary');
      }
    } catch (e) {
      AppConfig.logError('❌ Error loading cached tractor summary', e);
    }
  }

  Future<void> _loadCachedMaintenanceAlerts() async {
    try {
      final cachedAlerts = await _storageService.getString('maintenance_alerts_$_tractorId');
      if (cachedAlerts != null) {
        _maintenanceAlerts = jsonDecode(cachedAlerts);
        AppConfig.log('✅ Loaded cached maintenance alerts: ${_maintenanceAlerts?.length} alerts');
      }
    } catch (e) {
      AppConfig.logError('❌ Error loading cached maintenance alerts', e);
    }
  }

  Future<void> _loadCachedBaselineStatus() async {
    try {
      final cachedStatus = await _storageService.getString('baseline_status_$_tractorId');
      if (cachedStatus != null) {
        final statusData = jsonDecode(cachedStatus);
        setState(() {
          _hasBaseline = statusData['has_baseline'] == true;
        });
        AppConfig.log('✅ Loaded cached baseline status: $_hasBaseline');
      }
    } catch (e) {
      AppConfig.logError('❌ Error loading cached baseline status', e);
    }
  }

  Future<void> _checkBaselineStatus() async {
    if (_tractorId == null) return;
    
    try {
      AppConfig.log('📊 Checking baseline status for tractor: $_tractorId');
      
      // First try to get baseline history to see if any baselines exist
      try {
        final baselineHistory = await _apiService.getBaselineHistory(_tractorId!);
        final historyList = baselineHistory['history'] as List? ?? [];
        
        if (historyList.isNotEmpty) {
          setState(() {
            _hasBaseline = true;
          });
          
          // Cache the baseline status
          await _storageService.setString('baseline_status_$_tractorId', jsonEncode({
            'has_baseline': true,
            'last_updated': DateTime.now().toIso8601String(),
          }));
          
          AppConfig.log('✅ Baseline found in history: ${historyList.length} baselines');
          return;
        }
      } catch (e) {
        AppConfig.logError('❌ Failed to get baseline history', e);
      }
      
      // If history check fails, try baseline status
      try {
        final baselineStatus = await _apiService.getBaselineStatus(_tractorId!);
        AppConfig.log('📊 Baseline status response: $baselineStatus');
        
        final hasBaseline = baselineStatus['status'] == 'completed' || 
                           baselineStatus['status'] == 'active' ||
                           baselineStatus['has_active_baseline'] == true ||
                           baselineStatus['baseline_id'] != null;
        
        setState(() {
          _hasBaseline = hasBaseline;
        });
        
        // Cache the baseline status
        await _storageService.setString('baseline_status_$_tractorId', jsonEncode({
          'has_baseline': hasBaseline,
          'status': baselineStatus['status'],
          'last_updated': DateTime.now().toIso8601String(),
        }));
        
        AppConfig.log('✅ Baseline status loaded: hasBaseline = $_hasBaseline, status = ${baselineStatus['status']}');
      } catch (e) {
        AppConfig.logError('❌ Failed to get baseline status', e);
        // Try to load from cache when API fails
        await _loadCachedBaselineStatus();
      }
      
    } catch (e) {
      AppConfig.logError('❌ Failed to check baseline status', e);
      // Try to load from cache when everything fails
      await _loadCachedBaselineStatus();
    }
  }

  // Helper method to safely parse double values that might come as strings
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tractor Details'),
        actions: [
          // Connection status indicator
          Consumer<OfflineSyncService>(
            builder: (context, offlineSync, child) {
              return IconButton(
                icon: Icon(
                  offlineSync.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: offlineSync.isOnline ? Colors.green : Colors.orange,
                ),
                onPressed: () async {
                  await offlineSync.refreshConnectivity();
                  if (offlineSync.isOnline) {
                    await _loadMaintenanceData();
                  }
                },
                tooltip: offlineSync.isOnline ? 'Online' : 'Offline - showing cached data',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TractorProvider>(
              builder: (context, provider, child) {
                final tractor = provider.selectedTractor;

                if (tractor == null) {
                  return const Center(
                    child: Text('Tractor not found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        _buildHeaderCard(tractor),

                        const SizedBox(height: 16),

                        // Quick Actions 
                        _buildQuickActions(tractor),

                        const SizedBox(height: 16),

                        // Maintenance alerts
                        _buildMaintenanceAlertsCard(),

                        const SizedBox(height: 16),

                        // Usage History
                        _buildUsageHistoryCard(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeaderCard(Tractor tractor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.successGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tractor Icon - larger and more prominent
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.agriculture,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Tractor Info - centered section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tractor.model,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tractor.tractorId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (tractor.purchaseYear != null) ...[
                    Text(
                      'Purchased: ${tractor.purchaseYear}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    'Engine Hours: ${tractor.formattedEngineHours}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status and Baseline - horizontal layout as shown in image
            Row(
              children: [
                // Status Section
                Column(
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                
                // Baseline Section
                Column(
                  children: [
                    const Text(
                      'Baseline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _hasBaseline ? Icons.check_circle : Icons.close,
                        color: _hasBaseline ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Tractor tractor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.mic,
              label: 'Test Sound',
              color: AppColors.success,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/recording',
                  arguments: {
                    'tractor_id': tractor.tractorId,
                    'engine_hours': tractor.engineHours,
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.schedule,
              label: 'Usage',
              color: AppColors.primary,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/usage-history',
                  arguments: {
                    'tractor_id': tractor.tractorId,
                    'engine_hours': tractor.engineHours,
                    'model': tractor.model,
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.build,
              label: 'Maintenance',
              color: AppColors.warning,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/maintenance',
                  arguments: tractor.tractorId,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.graphic_eq,
              label: 'Baseline',
              color: AppColors.info,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/baseline-collection',
                  arguments: {
                    'tractorId': tractor.tractorId,
                    'tractorHours': tractor.engineHours,
                    'model': tractor.model,
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Maintenance Summary (grid of stats)

  Widget _buildMaintenanceAlertsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Next Maintenance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Consumer<OfflineSyncService>(
                  builder: (context, offlineSync, child) {
                    if (!offlineSync.isOnline) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cached',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNextMaintenanceItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextMaintenanceItem() {
    // Get next maintenance from loaded data
    dynamic nextMaintenance;
    Color statusColor = Colors.orange;
    String statusText = 'Due Soon';
    
    if (_maintenanceAlerts != null && _maintenanceAlerts!.isNotEmpty) {
      // Sort alerts by due date and get the most urgent one
      final sortedAlerts = List<dynamic>.from(_maintenanceAlerts!)
        ..sort((a, b) {
          final aDate = DateTime.tryParse(a['due_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365));
          final bDate = DateTime.tryParse(b['due_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365));
          return aDate.compareTo(bDate);
        });
      
      nextMaintenance = sortedAlerts.first;
      
      // Determine status color based on urgency
      final dueDate = DateTime.tryParse(nextMaintenance['due_date']?.toString() ?? '');
      if (dueDate != null) {
        final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
        if (daysUntilDue < 0) {
          statusColor = Colors.red;
          statusText = 'Overdue';
        } else if (daysUntilDue <= 7) {
          statusColor = Colors.orange;
          statusText = 'Due Soon';
        } else {
          statusColor = Colors.green;
          statusText = 'Upcoming';
        }
      }
    } else if (_tractorSummary?.alerts != null && _tractorSummary!.alerts.isNotEmpty) {
      // Fallback to summary alerts
      final sortedAlerts = List.from(_tractorSummary!.alerts)
        ..sort((a, b) {
          final aDate = a.dueDate ?? DateTime.now().add(const Duration(days: 365));
          final bDate = b.dueDate ?? DateTime.now().add(const Duration(days: 365));
          return aDate.compareTo(bDate);
        });
      
      final alert = sortedAlerts.first;
      nextMaintenance = {
        'task_name': alert.task,
        'due_date': alert.dueDate?.toIso8601String(),
        'description': alert.description,
      };
    }

    // Get maintenance info
    final taskName = nextMaintenance?['task_name'] ?? nextMaintenance?['description'] ?? 'Engine oil and filter change';
    final dueInfo = _formatMaintenanceDue(nextMaintenance);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dueInfo,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMaintenanceDue(dynamic maintenance) {
    if (maintenance == null) return '20h or 70 remaining';
    
    final dueDate = DateTime.tryParse(maintenance['due_date']?.toString() ?? '');
    if (dueDate == null) return 'Due date not set';
    
    final now = DateTime.now();
    final difference = dueDate.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days remaining';
    } else if (difference.inDays == 0) {
      return 'Due today';
    } else {
      return '${difference.inDays.abs()} days overdue';
    }
  }



  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tractor'),
        content: const Text(
          'Are you sure you want to delete this tractor? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTractor();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTractor() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    
    final success = await tractorProvider.deleteTractor(_tractorId!);
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tractor deleted successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tractorProvider.error ?? 'Failed to delete tractor'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildUsageHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usage History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final tractor = Provider.of<TractorProvider>(context, listen: false).selectedTractor;
                    Navigator.pushNamed(
                      context,
                      '/usage-history',
                      arguments: {
                        'tractor_id': _tractorId!,
                        'engine_hours': tractor?.engineHours ?? 0,
                        'model': tractor?.model ?? 'Unknown Model',
                      },
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Simple usage history list (last 2 records)
            FutureBuilder<List<dynamic>>(
              future: _apiService.getUsageHistory(_tractorId!, days: 30),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  AppConfig.logError('Usage history error', snapshot.error);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load usage history',
                            style: TextStyle(color: AppColors.error),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check your internet connection and try again',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allHistory = snapshot.data ?? [];
                
                if (allHistory.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No usage logged yet'),
                    ),
                  );
                }

                // Show only last 2 records
                final recentHistory = allHistory.take(2).toList();

                return Column(
                  children: recentHistory.map<Widget>((record) {
                    final date = DateTime.parse(record['date']);
                    // Safely parse numeric values that might come as strings
                    final hoursUsed = _parseDouble(record['hours_used']) ?? 0.0;
                    final endHours = _parseDouble(record['end_hours']) ?? 0.0;
                    
                    return ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('${hoursUsed.toStringAsFixed(1)} hours used'),
                      trailing: Text(
                        '${endHours.toStringAsFixed(0)} hrs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

}