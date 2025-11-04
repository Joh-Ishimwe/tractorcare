// lib/screens/home/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; // <-- Make sure this is in pubspec.yaml
import '../../providers/auth_provider.dart';
import '../../providers/tractor_provider.dart';
import '../../models/tractor.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/api_connection_test.dart';
import '../../widgets/auth_debug_widget.dart';
import '../../widgets/debug_api_widget.dart';
import '../../widgets/custom_app_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

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

    try {
      await tractorProvider.fetchTractors();
      AppConfig.log('Tractors fetched: ${tractorProvider.tractors.length}');
    } catch (e) {
      AppConfig.logError('Failed to fetch tractors', e);
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
          for (var t in provider.tractors)
            t.tractorId: t.status == TractorStatus.critical
                ? AppColors.error
                : t.status == TractorStatus.warning
                    ? AppColors.warning
                    : AppColors.success
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
            TextButton(onPressed: () {}, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildActivityItem(
              Icons.info_outline,
              'No recent activity',
              'Start by adding a tractor or running an audio test',
              AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
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