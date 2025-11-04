// lib/screens/tractors/tractor_detail_screen.dart

// import 'dart:math' as math;
// import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/tractor_provider.dart';
import '../../providers/audio_provider.dart';
import '../../models/tractor.dart';
import '../../config/colors.dart';
import '../../services/api_service.dart';
import '../usage/usage_history_screen.dart';

class TractorDetailScreen extends StatefulWidget {
  const TractorDetailScreen({super.key});

  @override
  State<TractorDetailScreen> createState() => _TractorDetailScreenState();
}

class _TractorDetailScreenState extends State<TractorDetailScreen> {
  String? _tractorId;
  bool _isLoading = true;
  Map<String, dynamic>? _usageStats;
  Map<String, dynamic>? _summary; // maintenance summary
  Map<String, dynamic>? _nextTask; // next maintenance task
  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tractorId == null) {
      _tractorId = ModalRoute.of(context)!.settings.arguments as String;
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
    await audioProvider.fetchPredictions(_tractorId!, limit: 5);
    
    // Load usage statistics
    try {
      final stats = await _apiService.getUsageStats(_tractorId!);
      if (stats.containsKey('usage_last_7_days') &&
          stats.containsKey('usage_last_30_days')) {
        setState(() {
          _usageStats = stats;
        });
      }
    } catch (e) {
      print('Error loading usage stats: $e');
    }

    // Load maintenance summary (alerts, next task, etc.)
    try {
      final summary = await _apiService.getTractorSummary(_tractorId!);
      Map<String, dynamic>? nextTask;
      if (summary['alerts'] is List) {
        final List alerts = List.from(summary['alerts']);
        alerts.sort((a, b) {
          final ad = DateTime.tryParse(a['due_date'].toString()) ?? DateTime.now();
          final bd = DateTime.tryParse(b['due_date'].toString()) ?? DateTime.now();
          return ad.compareTo(bd);
        });
        nextTask = alerts.isNotEmpty ? Map<String, dynamic>.from(alerts.first) : null;
      }
      setState(() {
        _summary = Map<String, dynamic>.from(summary);
        _nextTask = nextTask;
      });
    } catch (e) {
      print('Error loading tractor summary: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tractor Details'),
        actions: [
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

                        const SizedBox(height: 12),

                        // Quick Actions (up top)
                        _buildQuickActions(tractor),

                        const SizedBox(height: 16),

                        // Maintenance Summary (stats cards)
                        _buildMaintenanceSummary(),

                        const SizedBox(height: 16),

                        // Next Maintenance
                        _buildNextMaintenanceCard(),

                        const SizedBox(height: 16),

                        // Info Card
                        _buildInfoCard(tractor),

                        const SizedBox(height: 16),

                        // Current Hours Display
                        _buildCurrentHoursCard(tractor),

                        const SizedBox(height: 16),

                        // Usage Statistics
                        _buildUsageStatsCard(),

                        const SizedBox(height: 16),

                        // Usage History Preview
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(tractor.status),
            _getStatusColor(tractor.status).withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            tractor.statusIcon,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            tractor.tractorId,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tractor.model,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tractor.statusText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Tractor tractor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tractor Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.access_time,
              'Engine Hours',
              tractor.formattedEngineHours,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Age',
              tractor.tractorAge,
            ),
            if (tractor.purchaseYear != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.shopping_cart,
                'Purchase Year',
                tractor.purchaseYear.toString(),
              ),
            ],
            if (tractor.lastCheckDate != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.check_circle,
                'Last Check',
                tractor.timeSinceLastCheck,
              ),
            ],
            if (tractor.notes != null && tractor.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.notes,
                'Notes',
                tractor.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(Tractor tractor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.mic,
                  label: 'Test Audio',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/audio-test',
                      arguments: tractor.tractorId,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.graphic_eq,
                  label: 'Setup Baseline',
                  color: AppColors.info,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/baseline-collection',
                      arguments: tractor.tractorId,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.show_chart,
                  label: 'Statistics',
                  color: AppColors.success,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Statistics coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Maintenance Summary (grid of stats)
  Widget _buildMaintenanceSummary() {
    if (_summary == null) return const SizedBox();

    final totalAlerts = _summary!['total_alerts'] ?? 0;
    final overdue = _summary!['overdue_alerts'] ?? 0;
    final high = _summary!['high_priority_alerts'] ?? 0;
    final estTimeHrs = (_summary!['total_estimated_time_hours'] ?? 0).toString();
    final totalSpent = _summary!['total_spent_rwf'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Maintenance Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              _buildStatTile(Icons.notifications, 'Total Alerts', '$totalAlerts', Colors.blue),
              _buildStatTile(Icons.error, 'Overdue', '$overdue', Colors.red),
              _buildStatTile(Icons.priority_high, 'High Priority', '$high', Colors.orange),
              _buildStatTile(Icons.timer, 'Est. Time', '${estTimeHrs}h', Colors.teal),
              if (totalSpent != null)
                _buildStatTile(Icons.attach_money, 'Total Spent', '$totalSpent RWF', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Next Maintenance card
  Widget _buildNextMaintenanceCard() {
    if (_nextTask == null) return const SizedBox();

    final title = _nextTask!['task_name'] ?? 'Upcoming maintenance';
    final dueStr = _nextTask!['due_date']?.toString();
    final dueDate = dueStr != null ? DateTime.tryParse(dueStr) : null;
    final remaining = _formatRemaining(dueDate);
    final priority = (_nextTask!['priority']?.toString() ?? '').toLowerCase();
    final color = priority == 'critical'
        ? Colors.red
        : priority == 'high'
            ? Colors.orange
            : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_nextTask!['estimated_time_minutes'] != null)
                Text(
                  '${_nextTask!['estimated_time_minutes']}m',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRemaining(DateTime? due) {
    if (due == null) return 'Due date unknown';
    final now = DateTime.now();
    final diff = due.difference(now);
    if (diff.inDays >= 1) return '${diff.inDays}d remaining';
    if (diff.inHours >= 1) return '${diff.inHours}h remaining';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m remaining';
    return 'Due now';
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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

  Widget _buildCurrentHoursCard(Tractor tractor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Engine Hours',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${tractor.engineHours} hrs',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 32),
              onPressed: () => _showLogHoursDialog(tractor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStatsCard() {
    if (_usageStats == null) return const SizedBox();

    final last7Days = _usageStats!['usage_last_7_days'];
    final last30Days = _usageStats!['usage_last_30_days'];
    final totalHours = (last7Days['total_hours'] + last30Days['total_hours']).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usage Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Pie Chart
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _getPieChartSections(last7Days, last30Days),
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                          enabled: true,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Legend and Stats
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Center total
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${totalHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Total Hours',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Legend
                        _buildLegendItem(
                          'Last 7 Days',
                          '${last7Days['total_hours']}h',
                          Colors.green,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Previous 23 Days',
                          '${(last30Days['total_hours'] - last7Days['total_hours']).toStringAsFixed(1)}h',
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Idle Time',
                          '${(168 - totalHours).toStringAsFixed(1)}h', // 7 days * 24 hours
                          Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsageHistoryScreen(
                          tractorId: _tractorId!,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Simple usage history list (last 5 days)
            FutureBuilder<List<dynamic>>(
              future: _apiService.getUsageHistory(_tractorId!, days: 5),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final history = snapshot.data!;
                
                if (history.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No usage logged yet'),
                    ),
                  );
                }

                return Column(
                  children: history.map<Widget>((record) {
                    final date = DateTime.parse(record['date']);
                    final hoursUsed = record['hours_used'];
                    
                    return ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('${hoursUsed.toStringAsFixed(1)} hours used'),
                      trailing: Text(
                        '${record['end_hours']} hrs',
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

  void _showLogHoursDialog(Tractor tractor) {
    final hoursController = TextEditingController(
      text: tractor.engineHours.toString(),
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Engine Hours'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hoursController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Current Engine Hours',
                    hintText: 'e.g., 52.5',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'What work was done today?',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final endHours = double.parse(hoursController.text);
                  
                  await _apiService.logDailyUsage(
                    _tractorId!,
                    endHours,
                    notesController.text.isEmpty ? null : notesController.text,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Hours logged successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    // Refresh data
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Log Hours'),
            ),
          ],
        );
      },
    );
  }

  List<PieChartSectionData> _getPieChartSections(Map<String, dynamic> last7Days, Map<String, dynamic> last30Days) {
    final last7DaysHours = (last7Days['total_hours'] as num).toDouble();
    final previousDaysHours = ((last30Days['total_hours'] as num) - (last7Days['total_hours'] as num)).toDouble();
    final idleHours = 168.0 - (last7DaysHours + previousDaysHours); // 7 days * 24 hours
    
    return [
      PieChartSectionData(
        color: Colors.green,
        value: last7DaysHours,
        title: '${last7DaysHours.toStringAsFixed(1)}h',
        radius: 35,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: previousDaysHours,
        title: '${previousDaysHours.toStringAsFixed(1)}h',
        radius: 35,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.grey.shade300,
        value: idleHours > 0 ? idleHours : 0,
        title: idleHours > 0 ? '${idleHours.toStringAsFixed(0)}h' : '',
        radius: 30,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    ];
  }

  Widget _buildLegendItem(String title, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }




  Color _getStatusColor(TractorStatus status) {
    switch (status) {
      case TractorStatus.good:
        return AppColors.success;
      case TractorStatus.warning:
        return AppColors.warning;
      case TractorStatus.critical:
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }
}