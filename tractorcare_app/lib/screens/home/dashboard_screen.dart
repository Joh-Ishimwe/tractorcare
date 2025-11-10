import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // <-- Make sure this is in pubspec.yaml
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tractor_provider.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/api_connection_test.dart';
import '../../widgets/auth_debug_widget.dart';
import '../../widgets/debug_api_widget.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/connection_status_widget.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/offline_sync_service.dart';
import '../../models/maintenance.dart';
import '../../models/tractor_summary.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<Maintenance> _allMaintenanceTasks = [];
  Map<String, TractorSummary> _tractorSummaries = {};
  Map<String, List<dynamic>> _usageHistoryData = {};
  bool _isLoadingActivities = false;
  bool _isLoadingUsageData = false;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);

    AppConfig.log('Dashboard loading data... (${offlineSyncService.isOnline ? 'Online' : 'Offline'})');
    if (!authProvider.isAuthenticated) {
      AppConfig.logError('User not authenticated, redirecting to login');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() => _isLoadingActivities = true);

    try {
      // Load tractors (provider already handles offline/online)
      await tractorProvider.fetchTractors();
      AppConfig.log('Tractors fetched: ${tractorProvider.tractors.length}');
      
      if (offlineSyncService.isOnline) {
        // Online: Load fresh data and cache it
        await tractorProvider.loadRecentPredictions();
        AppConfig.log('Recent predictions loaded for status determination');
        
        await _loadMaintenanceActivities();
        await _loadUsageData();
      } else {
        // Offline: Load cached data
        await _loadCachedMaintenanceActivities();
        await _loadCachedUsageData();
        AppConfig.log('Loaded cached dashboard data');
      }
    } catch (e) {
      AppConfig.logError('Failed to fetch dashboard data', e);
      // Fall back to cached data on error
      await _loadCachedMaintenanceActivities();
      await _loadCachedUsageData();
    } finally {
      if (mounted) setState(() => _isLoadingActivities = false);
    }
  }

  Future<void> _loadMaintenanceActivities() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final apiService = ApiService();
    
    AppConfig.log('Loading maintenance activities for ${tractorProvider.tractors.length} tractors');
    
    List<Maintenance> allTasks = [];
    Map<String, TractorSummary> summaries = {};

    for (final tractor in tractorProvider.tractors) {
      try {
        // Get maintenance alerts for this tractor
        final tasks = await apiService.getMaintenanceTasks(tractor.tractorId, completed: false);
        allTasks.addAll(tasks);
        
        // Cache maintenance tasks
        await _storageService.setString('maintenance_tasks_${tractor.tractorId}', jsonEncode(
          tasks.map((task) => task.toJson()).toList()
        ));
        
        // Get tractor summary for usage data
        final summary = await apiService.getTractorSummary(tractor.tractorId);
        summaries[tractor.tractorId] = summary;
        
        // Cache tractor summary
        await _storageService.setString('tractor_summary_${tractor.tractorId}', jsonEncode(summary.toJson()));
        
        AppConfig.log('Loaded ${tasks.length} maintenance tasks for tractor ${tractor.tractorId}');
      } catch (e) {
        AppConfig.logError('Failed to load data for tractor ${tractor.tractorId}', e);
        // Try to load cached data for this tractor
        await _loadCachedDataForTractor(tractor.tractorId, allTasks, summaries);
      }
    }

    if (mounted) {
      setState(() {
        _allMaintenanceTasks = allTasks;
        _tractorSummaries = summaries;
      });
    }
  }

  Future<void> _loadCachedMaintenanceActivities() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    
    AppConfig.log('Loading cached maintenance activities for ${tractorProvider.tractors.length} tractors');
    
    List<Maintenance> allTasks = [];
    Map<String, TractorSummary> summaries = {};

    for (final tractor in tractorProvider.tractors) {
      await _loadCachedDataForTractor(tractor.tractorId, allTasks, summaries);
    }

    if (mounted) {
      setState(() {
        _allMaintenanceTasks = allTasks;
        _tractorSummaries = summaries;
      });
    }
  }

  Future<void> _loadCachedDataForTractor(String tractorId, List<Maintenance> allTasks, Map<String, TractorSummary> summaries) async {
    try {
      // Load cached maintenance tasks
      final cachedTasks = await _storageService.getString('maintenance_tasks_$tractorId');
      if (cachedTasks != null) {
        final tasksData = jsonDecode(cachedTasks) as List;
        final tasks = tasksData.map((taskData) => Maintenance.fromJson(taskData)).toList();
        allTasks.addAll(tasks);
        AppConfig.log('Loaded ${tasks.length} cached maintenance tasks for tractor $tractorId');
      }
      
      // Load cached tractor summary
      final cachedSummary = await _storageService.getString('tractor_summary_$tractorId');
      if (cachedSummary != null) {
        final summaryData = jsonDecode(cachedSummary);
        summaries[tractorId] = TractorSummary.fromJson(summaryData);
        AppConfig.log('Loaded cached tractor summary for $tractorId');
      }
    } catch (e) {
      AppConfig.logError('Failed to load cached data for tractor $tractorId', e);
    }
  }

  Future<void> _loadUsageData() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final apiService = ApiService();
    
    setState(() => _isLoadingUsageData = true);
    
    AppConfig.log('Loading usage data for ${tractorProvider.tractors.length} tractors');
    
    Map<String, List<dynamic>> usageData = {};

    for (final tractor in tractorProvider.tractors) {
      try {
        // Get usage history for last 7 days
        final history = await apiService.getUsageHistory(tractor.tractorId, days: 7);
        usageData[tractor.tractorId] = history;
        
        // Cache usage data
        await _storageService.setString('usage_history_dashboard_${tractor.tractorId}', jsonEncode(history));
        
        AppConfig.log('Loaded usage history for tractor ${tractor.tractorId}: ${history.length} records');
      } catch (e) {
        AppConfig.logError('Failed to load usage data for tractor ${tractor.tractorId}', e);
        // Try to load cached usage data
        await _loadCachedUsageDataForTractor(tractor.tractorId, usageData);
      }
    }

    if (mounted) {
      setState(() {
        _usageHistoryData = usageData;
        _isLoadingUsageData = false;
      });
    }
  }

  Future<void> _loadCachedUsageData() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    
    setState(() => _isLoadingUsageData = true);
    
    AppConfig.log('Loading cached usage data for ${tractorProvider.tractors.length} tractors');
    
    Map<String, List<dynamic>> usageData = {};

    for (final tractor in tractorProvider.tractors) {
      await _loadCachedUsageDataForTractor(tractor.tractorId, usageData);
    }

    if (mounted) {
      setState(() {
        _usageHistoryData = usageData;
        _isLoadingUsageData = false;
      });
    }
  }

  Future<void> _loadCachedUsageDataForTractor(String tractorId, Map<String, List<dynamic>> usageData) async {
    try {
      final cachedUsage = await _storageService.getString('usage_history_dashboard_$tractorId');
      if (cachedUsage != null) {
        usageData[tractorId] = jsonDecode(cachedUsage);
        AppConfig.log('Loaded cached usage history for tractor $tractorId');
      } else {
        // Set empty list if no cached data
        usageData[tractorId] = [];
      }
    } catch (e) {
      AppConfig.logError('Failed to load cached usage data for tractor $tractorId', e);
      usageData[tractorId] = [];
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/tractors');
        break;
      case 2:
        _showTractorSelectionForAudioTest();
        break;
      case 3:
        Navigator.pushNamed(context, '/maintenance');
        break;
    }
  }

  void _showTractorSelectionForAudioTest() {
    final provider = Provider.of<TractorProvider>(context, listen: false);
    final tractors = provider.tractors;

    if (tractors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tractors available. Please add a tractor first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Tractor for Audio Test',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose which tractor you want to test',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ...tractors.map((tractor) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.success.withOpacity(0.1),
                  child: const Icon(
                    Icons.agriculture,
                    color: AppColors.success,
                  ),
                ),
                title: Text(
                  tractor.tractorId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${tractor.model} • ${tractor.engineHours} hours',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                trailing: const Icon(
                  Icons.mic,
                  color: AppColors.success,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  // Navigate directly to recording screen
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
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Navigate to the tractor with the most recent critical issue
  void _navigateToCriticalTractor(TractorProvider provider) {
    final criticalTractor = provider.getMostRecentCriticalTractor();
    if (criticalTractor != null) {
      Navigator.pushNamed(
        context,
        '/tractor-detail',
        arguments: criticalTractor.tractorId,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No critical issues found'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  // Navigate to the tractor with the most recent warning issue
  void _navigateToWarningTractor(TractorProvider provider) {
    final warningTractor = provider.getMostRecentWarningTractor();
    if (warningTractor != null) {
      Navigator.pushNamed(
        context,
        '/tractor-detail',
        arguments: warningTractor.tractorId,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No warning issues found'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Dashboard'),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection status widget
              const ConnectionStatusWidget(),
              _buildApiStatus(),
              if (AppConfig.debugMode) const ApiConnectionTest(),
              if (AppConfig.debugMode) const AuthDebugWidget(),
              if (AppConfig.debugMode) const DebugApiWidget(),

              _buildQuickStats(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildHoursBarChart(),
              const SizedBox(height: 24),
              _buildRecentActivity(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  // ==================== QUICK STATS ====================
  Widget _buildQuickStats() {
    return Consumer<TractorProvider>(
      builder: (context, provider, child) {
        final totalTractors = provider.tractors.length;
        final criticalTractors = provider.getCriticalTractors().length;
        final warningTractors = provider.getWarningTractors().length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildClickableStatCard(
                    Icons.agriculture,
                    totalTractors.toString(),
                    'Total Tractors',
                    AppColors.primary,
                    () => Navigator.pushNamed(context, '/tractors'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildClickableStatCard(
                    Icons.warning, 
                    warningTractors.toString(), 
                    'Warnings', 
                    AppColors.warning,
                    () => _navigateToWarningTractor(provider),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildClickableStatCard(
                    Icons.error, 
                    criticalTractors.toString(), 
                    'Critical', 
                    AppColors.error,
                    () => _navigateToCriticalTractor(provider),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildClickableStatCard(IconData icon, String value, String label, Color color, VoidCallback? onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== QUICK ACTIONS (3 in row) ====================
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                Icons.add,
                'Add Tractor',
                AppColors.primary,
                () => Navigator.pushNamed(context, '/add-tractor'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                Icons.graphic_eq,
                'Baseline',
                AppColors.warning,
                () => Navigator.pushNamed(context, '/baseline-setup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                Icons.calendar_today,
                'Calendar',
                AppColors.success,
                () => Navigator.pushNamed(context, '/calendar'), // Update route if needed
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== USAGE DATA PROCESSING ====================
  Map<String, List<double>> _buildUsageDataForChart(List<String> tractorIds, List<DateTime> last7Days) {
    Map<String, List<double>> hoursData = {};
    
    for (var tractorId in tractorIds) {
      List<double> dailyHours = [];
      final usageHistory = _usageHistoryData[tractorId] ?? [];
      
      // For each of the last 7 days, find the usage hours
      for (var day in last7Days) {
        double hoursForDay = 0.0;
        
        // Look for usage records on this day
        for (var record in usageHistory) {
          if (record['date'] != null) {
            try {
              final recordDate = DateTime.parse(record['date']);
              if (recordDate.year == day.year && 
                  recordDate.month == day.month && 
                  recordDate.day == day.day) {
                hoursForDay += (record['hours_used'] ?? 0.0).toDouble();
              }
            } catch (e) {
              AppConfig.logError('Error parsing date in usage record: $e');
            }
          }
        }
        
        dailyHours.add(hoursForDay);
      }
      
      hoursData[tractorId] = dailyHours;
    }
    
    return hoursData;
  }

  // ==================== BAR CHART: Hours per Day per Tractor ====================
  Widget _buildHoursBarChart() {
    return Consumer<TractorProvider>(
      builder: (context, provider, child) {
        if (provider.tractors.isEmpty) {
          return const SizedBox.shrink();
        }

        if (_isLoadingUsageData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Usage (Last 7 Days)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading usage data...'),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final last7Days = List.generate(7, (i) {
          return DateTime.now().subtract(Duration(days: 6 - i));
        });

        final tractorIds = provider.tractors.map((t) => t.tractorId).toList();
        final Map<String, Color> statusColor = {
          for (var t in provider.tractors.asMap().entries)
            t.value.tractorId: AppColors.chartColors[t.key % AppColors.chartColors.length]
        };

        // === LIVE DATA: Get real hours from usage history ===
        final Map<String, List<double>> hoursData = _buildUsageDataForChart(tractorIds, last7Days);
        
        // Debug: Log the chart data
        AppConfig.log('Chart Data for ${tractorIds.length} tractors:');
        for (var entry in hoursData.entries) {
          AppConfig.log('  ${entry.key}: ${entry.value}');
        }
        
        // Calculate dynamic maxY based on actual data, minimum 5
        double maxUsage = 5.0; // Minimum scale
        for (var tractorData in hoursData.values) {
          for (var hours in tractorData) {
            if (hours > maxUsage) maxUsage = hours;
          }
        }
        // Round up to next multiple of 5 for better scale
        maxUsage = ((maxUsage / 5).ceil() * 5).toDouble();
        if (maxUsage < 5) maxUsage = 5.0;
        
        AppConfig.log('Chart maxY set to: $maxUsage');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Usage (Last 7 Days)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxUsage,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey.withValues(alpha: 0.9),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final tractorId = tractorIds[rodIndex % tractorIds.length];
                        return BarTooltipItem(
                          '$tractorId\n${rod.toY.toStringAsFixed(1)} hrs',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: maxUsage <= 5 ? 1 : (maxUsage / 5).ceil().toDouble(),
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}h',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final day = last7Days[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${day.day}/${day.month}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300]!, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (dayIndex) {
                    return BarChartGroupData(
                      x: dayIndex,
                      barRods: tractorIds.asMap().entries.map((entry) {
                        final tractorId = entry.value;
                        final hours = hoursData[tractorId]?[dayIndex] ?? 0.0;
                        return BarChartRodData(
                          toY: hours,
                          color: statusColor[tractorId],
                          width: tractorIds.length == 1 ? 28 : 14, // Wider bars for single tractor
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLegend(tractorIds, statusColor),
          ],
        );
      },
    );
  }

  Widget _buildLegend(List<String> tractorIds, Map<String, Color> colors) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: tractorIds.take(6).map((id) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, color: colors[id]),
            const SizedBox(width: 6),
            Text(id, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        );
      }).toList(),
    );
  }

  // ==================== RECENT ACTIVITY ====================
  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/maintenance'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingActivities)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading maintenance activities...'),
                ],
              ),
            ),
          )
        else if (_allMaintenanceTasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildActivityItem(
                Icons.info_outline,
                'No maintenance activities',
                'All tractors are up to date with maintenance',
                AppColors.textTertiary,
              ),
            ),
          )
        else
          ..._buildMaintenanceActivityCards(),
        
        const SizedBox(height: 12),
        _buildUsageComparisonCard(),
      ],
    );
  }

  List<Widget> _buildMaintenanceActivityCards() {
    // Sort maintenance tasks by priority: overdue -> due -> upcoming
    final sortedTasks = List<Maintenance>.from(_allMaintenanceTasks);
    sortedTasks.sort((a, b) {
      final aScore = a.status == MaintenanceStatus.overdue ? 3 
                   : a.status == MaintenanceStatus.due ? 2 
                   : 1;
      final bScore = b.status == MaintenanceStatus.overdue ? 3 
                   : b.status == MaintenanceStatus.due ? 2 
                   : 1;
      
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.dueDate.compareTo(b.dueDate);
    });

    // Show up to 3 most important maintenance items
    final tasksToShow = sortedTasks.take(3);
    
    return tasksToShow.map((task) {
      final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
      final tractor = tractorProvider.tractors.firstWhere(
        (t) => t.id == task.tractorId,
        orElse: () => tractorProvider.tractors.first, // Fallback
      );
      
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildMaintenanceActivityItem(task, tractor.model),
        ),
      );
    }).toList();
  }

  Widget _buildMaintenanceActivityItem(Maintenance task, String tractorName) {
    IconData icon;
    Color color;
    String statusText;
    
    switch (task.status) {
      case MaintenanceStatus.overdue:
        icon = Icons.warning;
        color = Colors.red;
        statusText = 'OVERDUE';
        break;
      case MaintenanceStatus.due:
        icon = Icons.schedule;
        color = Colors.orange;
        statusText = 'DUE SOON';
        break;
      default:
        icon = Icons.calendar_today;
        color = AppColors.primary;
        statusText = 'UPCOMING';
    }
    
    final daysDiff = task.dueDate.difference(DateTime.now()).inDays;
    final dueDateText = daysDiff < 0 
        ? '${-daysDiff} days overdue'
        : daysDiff == 0 
            ? 'Due today'
            : daysDiff <= 7
                ? 'Due in $daysDiff days'
                : DateFormat('MMM dd, yyyy').format(task.dueDate);
    
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.customType ?? 'Maintenance',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$tractorName • $dueDateText',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (task.notes != null && task.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.notes!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUsageComparisonCard() {
    if (_tractorSummaries.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Usage Comparison',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Engine hours across all tractors',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildUsageComparisonItems(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUsageComparisonItems() {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final items = <Widget>[];
    
    // Sort by engine hours descending
    final sortedSummaries = _tractorSummaries.entries.toList();
    sortedSummaries.sort((a, b) => b.value.engineHours.compareTo(a.value.engineHours));
    
    final maxHours = sortedSummaries.isNotEmpty ? sortedSummaries.first.value.engineHours : 1.0;
    
    for (final entry in sortedSummaries.take(4)) { // Show top 4 tractors
      final summary = entry.value;
      final tractor = tractorProvider.tractors.firstWhere(
        (t) => t.id == entry.key,
        orElse: () => tractorProvider.tractors.first,
      );
      
      final percentage = maxHours > 0 ? (summary.engineHours / maxHours) : 0.0;
      
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  tractor.model,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${summary.engineHours.toInt()}h',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return items;
  }

  Widget _buildActivityItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== API STATUS (DEBUG) ====================
  Widget _buildApiStatus() {
    if (!AppConfig.debugMode) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConfig.isProduction ? Colors.green[100] : Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConfig.isProduction ? Colors.green : Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          Icon(AppConfig.isProduction ? Icons.cloud_done : Icons.construction,
              color: AppConfig.isProduction ? Colors.green[700] : Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(AppConfig.apiStatus,
                style: TextStyle(
                    color: AppConfig.isProduction ? Colors.green[700] : Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Text(AppConfig.isProduction ? 'LIVE' : 'DEV',
              style: TextStyle(
                  color: AppConfig.isProduction ? Colors.green[700] : Colors.orange[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}