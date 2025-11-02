// lib/widgets/auth_debug_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class AuthDebugWidget extends StatelessWidget {
  const AuthDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.debugMode) return const SizedBox.shrink();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Card(
          margin: const EdgeInsets.all(8),
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auth Debug',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDebugRow('Authenticated', '${authProvider.isAuthenticated}'),
                _buildDebugRow('User', authProvider.currentUser?.email ?? 'None'),
                _buildDebugRow('Loading', '${authProvider.isLoading}'),
                if (authProvider.error != null)
                  _buildDebugRow('Error', authProvider.error!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _testTokenValidity(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Test Token'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => authProvider.refreshAuth(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testTokenValidity(BuildContext context) async {
    final apiService = ApiService();
    
    try {
      AppConfig.log('🧪 Testing current user endpoint...');
      await apiService.getCurrentUser();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Token is valid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppConfig.logError('Token test failed', e);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Token invalid: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}