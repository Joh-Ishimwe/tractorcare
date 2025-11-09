// lib/widgets/connection_status_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_sync_service.dart';
import '../config/routes.dart';

class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineSyncService>(
      builder: (context, offlineSync, child) {
        if (offlineSync.isOnline && offlineSync.pendingChangesCount == 0) {
          // Online and synced - don't show anything
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            // Navigate to pending sync screen when tapped
            Navigator.pushNamed(context, AppRoutes.pendingSync);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: _getStatusColor(offlineSync),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(offlineSync),
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(offlineSync),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (offlineSync.isSyncing) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.touch_app,
                  size: 12,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(OfflineSyncService offlineSync) {
    if (offlineSync.isSyncing) {
      return Colors.orange;
    } else if (!offlineSync.isOnline) {
      return Colors.red.shade600;
    } else if (offlineSync.pendingChangesCount > 0) {
      return Colors.amber.shade700;
    }
    return Colors.green;
  }

  IconData _getStatusIcon(OfflineSyncService offlineSync) {
    if (offlineSync.isSyncing) {
      return Icons.sync;
    } else if (!offlineSync.isOnline) {
      return Icons.cloud_off;
    } else if (offlineSync.pendingChangesCount > 0) {
      return Icons.cloud_upload;
    }
    return Icons.cloud_done;
  }

  String _getStatusText(OfflineSyncService offlineSync) {
    if (offlineSync.isSyncing) {
      return 'Syncing...';
    } else if (!offlineSync.isOnline) {
      return 'Offline Mode';
    } else if (offlineSync.pendingChangesCount > 0) {
      return '${offlineSync.pendingChangesCount} pending sync';
    }
    return 'Connected';
  }
}