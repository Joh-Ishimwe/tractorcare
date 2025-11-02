// lib/widgets/debug_api_widget.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../services/storage_service.dart';

class DebugApiWidget extends StatefulWidget {
  const DebugApiWidget({super.key});

  @override
  State<DebugApiWidget> createState() => _DebugApiWidgetState();
}

class _DebugApiWidgetState extends State<DebugApiWidget> {
  String _testResult = 'Click "Test API" to test tractor endpoint';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.debugMode) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.api,
                  size: 20,
                  color: Colors.purple[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'API Debug',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const LinearProgressIndicator()
            else
              ElevatedButton(
                onPressed: _testTractorsApi,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Test Tractors API'),
              ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _testResult,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testTractorsApi() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing API...';
    });

    try {
      // Get token from storage
      final storage = StorageService();
      final token = await storage.getToken();
      
      AppConfig.log('🧪 Testing tractors API with token: ${token != null}');
      
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final url = '${AppConfig.apiBaseUrl}/tractors/';
      AppConfig.log('📡 Making request to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      AppConfig.log('📊 Response status: ${response.statusCode}');
      AppConfig.log('📄 Response body: ${response.body}');
      
      String result = 'Status: ${response.statusCode}\\n';
      result += 'Headers sent: $headers\\n\\n';
      result += 'Response: ${response.body}';
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is List) {
            result += '\\n\\nParsed: Found ${data.length} tractors';
          } else if (data is Map) {
            result += '\\n\\nParsed: Map with keys: ${data.keys.toList()}';
          }
        } catch (e) {
          result += '\\n\\nJSON Parse Error: $e';
        }
      }
      
      setState(() {
        _testResult = result;
        _isLoading = false;
      });
    } catch (e) {
      AppConfig.logError('🧪 API test failed', e);
      setState(() {
        _testResult = 'Error: $e';
        _isLoading = false;
      });
    }
  }
}