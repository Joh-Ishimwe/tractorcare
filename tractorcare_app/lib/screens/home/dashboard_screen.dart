// lib/screens/home/dashboard_screen.dart

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
import '../../services/api_service.dart';
import '../../models/maintenance.dart';
import '../../models/tractor_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  List<Maintenance> _allMaintenanceTasks = [];
  Map<String, TractorSummary> _tractorSummaries = {};
  bool _isLoadingActivities = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);

    AppConfig.log('Dashboard loading data...');
    if (!authProvider.isAuthenticated) {
      AppConfig.logError('User not authenticated, redirecting to login');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() => _isLoadingActivities = true);

    try {
      await tractorProvider.fetchTractors();
      AppConfig.log('Tractors fetched: ${tractorProvider.tractors.length}');
      
      // Load maintenance data for all tractors
      await _loadMaintenanceActivities();
    } catch (e) {
      AppConfig.logError('Failed to fetch tractors', e);
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
        final tasks = await apiService.getMaintenanceTasks(tractor.id, completed: false);
        allTasks.addAll(tasks);
        
        // Get tractor summary for usage data
        final summary = await apiService.getTractorSummary(tractor.id);
        summaries[tractor.id] = summary;
        
        AppConfig.log('Loaded ${tasks.length} maintenance tasks for tractor ${tractor.id}');
      } catch (e) {
        AppConfig.logError('Failed to load data for tractor ${tractor.id}', e);
        // Continue with other tractors even if one fails
      }
    }

    if (mounted) {
      setState(() {
        _allMaintenanceTasks = allTasks;
        _tractorSummaries = summaries;
      });
    }
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 1:
      case 2:
        Navigator.pushNamed(context, '/tractors');
        break;
      case 3:
        Navigator.pushNamed(context, '/maintenance');
        break;
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
                  child: _buildStatCard(Icons.warning, warningTractors.toString(), 'Warnings', AppColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(Icons.error, criticalTractors.toString(), 'Critical', AppColors.error),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return _buildClickableStatCard(icon, value, label, color, null);
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

  // ==================== BAR CHART: Hours per Day per Tractor ====================
  Widget _buildHoursBarChart() {
    return Consumer<TractorProvider>(
      builder: (context, provider, child) {
        if (provider.tractors.isEmpty) {
          return const SizedBox.shrink();
        }

        final last7Days = List.generate(7, (i) {
          return DateTime.now().subtract(Duration(days: 6 - i));
        });

        final tractorIds = provider.tractors.map((t) => t.tractorId).toList();
        final Map<String, Color> statusColor = {
          for (var t in provider.tractors.asMap().entries)
            t.value.tractorId: AppColors.chartColors[t.key % AppColors.chartColors.length]
        };

        // === MOCK DATA: Replace with real hours from API later ===
        final Map<String, List<double>> hoursData = {
          for (var id in tractorIds)
            id: List.generate(7, (day) {
              final base = (id.hashCode.abs() % 6) + 1; // 1–6 hrs
              final variance = (day % 3) - 1; // -1, 0, +1
              return (base + variance).clamp(0.5, 8.0).toDouble();
            }),
        };

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
                  maxY: 10,
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
                        interval: 2,
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
                          width: 14,
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