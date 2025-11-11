// lib/screens/usage/usage_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
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
  
  late String tractorId;
  late int currentHours;
  late String model;
  
  List<dynamic> usageHistory = [];
  Map<String, dynamic>? usageStats;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    tractorId = args['tractor_id'];
    currentHours = args['engine_hours'];
    model = args['model'];
    
    _loadUsageData();
  }

  @override
  void dispose() {
    _endHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUsageData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Load usage history and stats
      final historyResponse = await apiService.getUsageHistory(tractorId);
      final statsResponse = await apiService.getUsageStats(tractorId);
      
      if (mounted) {
        setState(() {
          usageHistory = historyResponse;
          usageStats = statsResponse;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load usage data: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _logDailyUsage() async {
    final endHoursStr = _endHoursController.text.trim();
    if (endHoursStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter end hours')),
      );
      return;
    }

    final endHours = double.tryParse(endHoursStr);
    if (endHours == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for hours')),
      );
      return;
    }

    if (endHours <= currentHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('End hours must be greater than current hours ($currentHours)')),
      );
      return;
    }

    try {
      setState(() {
        isSubmitting = true;
        errorMessage = null;
      });

      final apiService = Provider.of<ApiService>(context, listen: false);
      
      await apiService.logDailyUsage(
        tractorId,
        endHours,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Clear form and reload data
      _endHoursController.clear();
      _notesController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usage logged successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Reload usage data
      await _loadUsageData();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log usage: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usage History - $model'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Status
                  _buildCurrentStatusCard(),
                  const SizedBox(height: 16),
                  
                  // Log New Usage
                  _buildLogUsageCard(),
                  const SizedBox(height: 16),
                  
                  // Usage Statistics
                  if (usageStats != null) _buildUsageStatsCard(),
                  const SizedBox(height: 16),
                  
                  // Usage History
                  _buildUsageHistoryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatusCard() {
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
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                      ),
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

  Widget _buildLogUsageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log Daily Usage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'End Hours',
                hintText: 'Enter hours after use (must be > $currentHours)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.schedule),
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
                onPressed: isSubmitting ? null : _logDailyUsage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Log Usage', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usage Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Hours',
                    '${usageStats!['total_hours'] ?? 0}',
                    Icons.schedule,
                    AppColors.info,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Weekly Avg',
                    '${usageStats!['weekly_average'] ?? 0}',
                    Icons.trending_up,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (usageStats!['next_maintenance'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.build, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next Maintenance: ${usageStats!['next_maintenance']['hours_until']} hours',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usage History (Last 7 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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

  Widget _buildUsageHistoryItem(Map<String, dynamic> usage) {
    final date = DateTime.parse(usage['date']);
    final hoursUsed = usage['hours_used']?.toDouble() ?? 0.0;
    final startHours = usage['start_hours']?.toDouble() ?? 0.0;
    final endHours = usage['end_hours']?.toDouble() ?? 0.0;
    final notes = usage['notes'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${hoursUsed.toStringAsFixed(1)}h',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
}