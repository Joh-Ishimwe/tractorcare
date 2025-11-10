import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/usage_provider.dart';
import '../../services/offline_sync_service.dart';
import '../../config/colors.dart';

class UsageHistoryScreen extends StatefulWidget {
  final String tractorId;

  const UsageHistoryScreen({super.key, required this.tractorId});

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen> {
  final TextEditingController _endHoursController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final OfflineSyncService _offlineSyncService = OfflineSyncService();
  
  late String tractorId;
  late int currentHours;
  late String model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      tractorId = args['tractor_id'] ?? widget.tractorId;
      currentHours = args['engine_hours'] ?? 0;
      model = args['model'] ?? 'Unknown Model';
    } else {
      tractorId = widget.tractorId;
      currentHours = 0;
      model = 'Unknown Model';
    }
    
    _loadUsageData();
  }

  @override
  void dispose() {
    _endHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUsageData() async {
    final usageProvider = Provider.of<UsageProvider>(context, listen: false);
    await usageProvider.fetchUsageHistory(tractorId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsageProvider>(
      builder: (context, usageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Usage History - $model'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              if (usageProvider.hasPendingLogs)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Badge(
                      label: Text('${usageProvider.pendingUsageLogs.length}'),
                      child: const Icon(Icons.sync),
                    ),
                    onPressed: () => _showPendingLogsDialog(context, usageProvider),
                    tooltip: 'Pending logs',
                  ),
                ),
              Consumer<OfflineSyncService>(
                builder: (context, offlineSync, child) {
                  return IconButton(
                    icon: Icon(
                      offlineSync.isOnline ? Icons.wifi : Icons.wifi_off,
                      color: offlineSync.isOnline ? Colors.green : Colors.red,
                    ),
                    onPressed: () async {
                      await offlineSync.refreshConnectivity();
                      if (offlineSync.isOnline) {
                        await usageProvider.fetchUsageHistory(tractorId, forceRefresh: true);
                      }
                    },
                    tooltip: offlineSync.isOnline ? 'Online' : 'Offline',
                  );
                },
              ),
            ],
          ),
          body: usageProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Status
                      _buildCurrentStatusCard(usageProvider),
                      const SizedBox(height: 16),
                      
                      // Log New Usage
                      _buildLogUsageCard(usageProvider),
                      const SizedBox(height: 16),
                      
                      // Usage History
                      _buildUsageHistoryCard(usageProvider),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _logDailyUsage() async {
    final usageProvider = Provider.of<UsageProvider>(context, listen: false);
    
    final hoursOperatedStr = _endHoursController.text.trim();
    if (hoursOperatedStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter hours operated today')),
      );
      return;
    }

    final hoursOperated = double.tryParse(hoursOperatedStr);
    if (hoursOperated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for hours')),
      );
      return;
    }

    if (hoursOperated <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hours operated must be greater than 0')),
      );
      return;
    }

    // Calculate new total hours
    final newTotalHours = currentHours + hoursOperated;

    final success = await usageProvider.logDailyUsage(
      tractorId,
      newTotalHours,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      // Update current hours locally
      currentHours = newTotalHours.toInt();

      // Clear form
      _endHoursController.clear();
      _notesController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _offlineSyncService.isOnline 
              ? 'Usage logged successfully!' 
              : 'Usage logged (will sync when online)'
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildCurrentStatusCard(UsageProvider usageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Current Hours: $currentHours',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (usageProvider.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        usageProvider.errorMessage!,
                        style: TextStyle(color: AppColors.warning, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (usageProvider.hasPendingLogs) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${usageProvider.pendingUsageLogs.length} pending log(s) to sync',
                        style: TextStyle(color: AppColors.info, fontSize: 14),
                      ),
                    ),
                    Consumer<OfflineSyncService>(
                      builder: (context, offlineSync, child) {
                        return TextButton.icon(
                          onPressed: offlineSync.isOnline ? () async {
                            final success = await usageProvider.manualSync();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success 
                                    ? 'Sync completed!' 
                                    : 'Some logs failed to sync'
                                  ),
                                  backgroundColor: success ? AppColors.success : AppColors.warning,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } : null,
                          icon: Icon(
                            Icons.upload,
                            size: 16,
                            color: offlineSync.isOnline ? AppColors.primary : Colors.grey,
                          ),
                          label: Text(
                            'Sync',
                            style: TextStyle(
                              color: offlineSync.isOnline ? AppColors.primary : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogUsageCard(UsageProvider usageProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log Today\'s Operation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter only the hours operated today. Current total: $currentHours hours',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hours Operated Today',
                hintText: 'Enter hours operated (e.g., 3.5)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any notes about the usage...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logDailyUsage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_offlineSyncService.isOnline) ...[
                      const Icon(Icons.offline_pin, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _offlineSyncService.isOnline ? 'Log Usage' : 'Log Usage (Offline)',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildUsageStatsCard() {
  //   // If usageStats is empty, show a message
  //   if (usageStats == null || usageStats!.isEmpty) {
  //     return Card(
  //       child: Padding(
  //         padding: const EdgeInsets.all(16.0),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               'Usage Statistics',
  //               style: TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //                 color: AppColors.textPrimary,
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             const Center(
  //               child: Text(
  //                 'No usage statistics available yet.\nLog some usage to see statistics.',
  //                 textAlign: TextAlign.center,
  //                 style: TextStyle(
  //                   color: AppColors.textSecondary,
  //                   fontSize: 16,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //   }

  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'Usage Statistics',
  //             style: TextStyle(
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //               color: AppColors.textPrimary,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: _buildStatItem(
  //                   'Total Hours',
  //                   '${usageStats!['total_hours'] ?? 0}',
  //                   Icons.schedule,
  //                   AppColors.info,
  //                 ),
  //               ),
  //               Expanded(
  //                 child: _buildStatItem(
  //                   'Weekly Avg',
  //                   '${usageStats!['weekly_average'] ?? 0}',
  //                   Icons.trending_up,
  //                   AppColors.success,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 12),
  //           if (usageStats!['next_maintenance'] != null) ...[
  //             Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: AppColors.warning.withOpacity(0.1),
  //                 borderRadius: BorderRadius.circular(8),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.build, color: AppColors.warning),
  //                   const SizedBox(width: 8),
  //                   Expanded(
  //                     child: Text(
  //                       'Next Maintenance: ${usageStats!['next_maintenance']['hours_until']} hours',
  //                       style: const TextStyle(fontWeight: FontWeight.w500),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildUsageHistoryCard(UsageProvider usageProvider) {
    final usageHistory = usageProvider.usageHistory;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                if (usageProvider.hasPendingLogs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${usageProvider.pendingUsageLogs.length} pending',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (usageHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No usage history available',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ...usageHistory.map((usage) => _buildUsageHistoryItem(usage)),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageHistoryItem(dynamic usage) {
    final Map<String, dynamic> usageMap = Map<String, dynamic>.from(usage);
    final date = DateTime.parse(usageMap['date']);
    final hoursUsed = usageMap['hours_used']?.toDouble() ?? 0.0;
    final startHours = usageMap['start_hours']?.toDouble() ?? 0.0;
    final endHours = usageMap['end_hours']?.toDouble() ?? 0.0;
    final notes = usageMap['notes'] as String?;
    final isPending = usageMap['isPending'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPending ? AppColors.warning.withOpacity(0.5) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isPending ? AppColors.warning.withOpacity(0.05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  if (isPending) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'PENDING',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPending ? '${endHours.toStringAsFixed(1)}h total' : '${hoursUsed.toStringAsFixed(1)}h',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isPending) ...[
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${startHours.toStringAsFixed(1)} → ${endHours.toStringAsFixed(1)} hours',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.sync, size: 16, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  'Waiting to sync - Total hours: ${endHours.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    notes,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPendingLogsDialog(BuildContext context, UsageProvider usageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Usage Logs'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${usageProvider.pendingUsageLogs.length} usage logs waiting to sync',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Consumer<OfflineSyncService>(
                builder: (context, offlineSync, child) {
                  return Text(
                    offlineSync.isOnline 
                      ? 'You are online. Logs will sync automatically.'
                      : 'You are offline. Logs will sync when connection is restored.',
                    style: TextStyle(
                      color: offlineSync.isOnline ? Colors.green : Colors.orange,
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (usageProvider.pendingUsageLogs.isNotEmpty)
            Consumer<OfflineSyncService>(
              builder: (context, offlineSync, child) {
                return TextButton(
                  onPressed: offlineSync.isOnline ? () async {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        content: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 16),
                            Text('Syncing...'),
                          ],
                        ),
                      ),
                    );

                    // Attempt sync
                    final success = await usageProvider.manualSync();
                    
                    if (mounted) {
                      Navigator.of(context).pop(); // Close loading dialog
                      Navigator.of(context).pop(); // Close pending logs dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success 
                            ? 'All logs synced successfully!' 
                            : 'Some logs failed to sync. Check your connection.'
                          ),
                          backgroundColor: success ? AppColors.success : AppColors.warning,
                        ),
                      );
                    }
                  } : null,
                  child: Text(
                    'Sync Now',
                    style: TextStyle(
                      color: offlineSync.isOnline ? AppColors.primary : Colors.grey,
                    ),
                  ),
                );
              },
            ),
          if (usageProvider.pendingUsageLogs.isNotEmpty)
            TextButton(
              onPressed: () async {
                await usageProvider.clearPendingLogs();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pending logs cleared'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
