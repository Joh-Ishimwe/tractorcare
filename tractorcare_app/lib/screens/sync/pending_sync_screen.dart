// lib/screens/sync/pending_sync_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/tractor_provider.dart';
import '../../services/offline_sync_service.dart';
import '../../config/colors.dart';
import '../../widgets/custom_app_bar.dart';

class PendingSyncScreen extends StatefulWidget {
  const PendingSyncScreen({super.key});

  @override
  State<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends State<PendingSyncScreen> {
  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPendingItems();
  }

  Future<void> _loadPendingItems() async {
    setState(() => _isLoading = true);
    
    try {
      final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
      final items = await tractorProvider.getPendingEdits();
      
      setState(() {
        _pendingItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load pending items: $e')),
        );
      }
    }
  }

  Future<void> _syncAll() async {
    final offlineSync = Provider.of<OfflineSyncService>(context, listen: false);
    
    if (!offlineSync.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot sync: No internet connection')),
      );
      return;
    }

    try {
      await offlineSync.syncPendingChanges();
      await _loadPendingItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully synced all changes')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _clearItem(int index) async {
    try {
      final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
      await tractorProvider.clearPendingEdit(index);
      await _loadPendingItems();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Pending Sync'),
      body: Consumer<OfflineSyncService>(
        builder: (context, offlineSync, child) {
          return Column(
            children: [
              // Header with sync status
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: offlineSync.isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: offlineSync.isOnline ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          offlineSync.isOnline ? Icons.cloud_done : Icons.cloud_off,
                          color: offlineSync.isOnline ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          offlineSync.isOnline ? 'Connected' : 'Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: offlineSync.isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (offlineSync.isSyncing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_pendingItems.length} changes waiting to sync',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (offlineSync.isOnline && _pendingItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: offlineSync.isSyncing ? null : _syncAll,
                          icon: const Icon(Icons.sync),
                          label: Text(offlineSync.isSyncing ? 'Syncing...' : 'Sync All Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Pending items list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pendingItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All changes synced!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No pending changes to synchronize',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pendingItems.length,
                            itemBuilder: (context, index) {
                              final item = _pendingItems[index];
                              return _buildPendingItem(item, index);
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingItem(Map<String, dynamic> item, int index) {
    final type = item['type'] as String;
    final timestamp = DateTime.parse(item['timestamp'] as String);
    final tractorId = item['tractorId'] as String? ?? 'Unknown';
    
    IconData icon;
    String title;
    String description;
    Color iconColor;
    
    switch (type) {
      case 'usage_log':
        icon = Icons.access_time;
        title = 'Usage Log Added';
        description = 'Hours logged for $tractorId';
        iconColor = Colors.blue;
        break;
      case 'maintenance_add':
        icon = Icons.build;
        title = 'Maintenance Record Added';
        description = 'New maintenance for $tractorId';
        iconColor = Colors.green;
        break;
      case 'maintenance_update':
        icon = Icons.edit;
        title = 'Maintenance Record Updated';
        description = 'Updated maintenance for $tractorId';
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.sync;
        title = 'Unknown Change';
        description = 'Change for $tractorId';
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              'Created: ${DateFormat('MMM dd, yyyy HH:mm').format(timestamp)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'clear') {
              _showClearConfirmation(index);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Clear'),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showClearConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Pending Change'),
        content: const Text(
          'Are you sure you want to clear this pending change? This action cannot be undone and the change will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearItem(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}