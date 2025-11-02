// lib/widgets/api_connection_test.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiConnectionTest extends StatefulWidget {
  const ApiConnectionTest({super.key});

  @override
  State<ApiConnectionTest> createState() => _ApiConnectionTestState();
}

class _ApiConnectionTestState extends State<ApiConnectionTest> {
  final Map<String, bool> _endpointStatus = {};
  bool _isLoading = false;

  final List<Map<String, String>> _endpoints = [
    {'name': 'API Root', 'path': '/'},
    {'name': 'API Docs', 'path': '/docs'},
    {'name': 'Auth Login', 'path': '${AppConfig.authEndpoint}/login'},
    {'name': 'Tractors', 'path': '${AppConfig.tractorsEndpoint}/'},
    {'name': 'Audio', 'path': '${AppConfig.audioEndpoint}/'},
    {'name': 'Maintenance', 'path': '${AppConfig.maintenanceEndpoint}/'},
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'API Connection Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton(
                    onPressed: _testAllEndpoints,
                    child: const Text('Test All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Backend: ${AppConfig.apiBaseUrl}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            ..._endpoints.map((endpoint) => _buildEndpointStatus(endpoint)),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointStatus(Map<String, String> endpoint) {
    final String name = endpoint['name']!;
    final bool? isOnline = _endpointStatus[name];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOnline == null 
                ? Icons.help_outline 
                : (isOnline ? Icons.check_circle : Icons.error),
            color: isOnline == null 
                ? Colors.grey 
                : (isOnline ? Colors.green : Colors.red),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            endpoint['path']!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testAllEndpoints() async {
    setState(() {
      _isLoading = true;
      _endpointStatus.clear();
    });

    for (final endpoint in _endpoints) {
      final name = endpoint['name']!;
      final path = endpoint['path']!;
      
      try {
        AppConfig.log('Testing endpoint: $name ($path)');
        
        final response = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}$path'),
          headers: AppConfig.getHeaders(token: null),
        ).timeout(const Duration(seconds: 10));
        
        final isSuccess = response.statusCode >= 200 && response.statusCode < 400;
        setState(() {
          _endpointStatus[name] = isSuccess;
        });
        
        AppConfig.log('$name: ${response.statusCode} ${isSuccess ? '✅' : '❌'}');
      } catch (e) {
        setState(() {
          _endpointStatus[name] = false;
        });
        AppConfig.logError('$name: Error', e);
      }
    }

    setState(() {
      _isLoading = false;
    });
    
    AppConfig.logSuccess('API connection test completed');
  }
}