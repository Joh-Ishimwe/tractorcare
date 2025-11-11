import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/tractor_provider.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../../config/colors.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  final ApiService _apiService = ApiService();
  
  // Additional analytics data
  List<FlSpot> _usageTrendData = [];
  List<FlSpot> _maintenanceTrendData = [];
  final Map<String, double> _monthlyUsage = {};
  final Map<String, int> _monthlyMaintenance = {};
  String _selectedTimeRange = '6M'; // 1M, 3M, 6M, 1Y

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Provider.of<TractorProvider>(context, listen: false).fetchTractors();
      
      // Load basic stats
      final stats = await _apiService.getUserStatistics();
      
      // Load enhanced analytics
      await _loadAnalytics();
      
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
      AppConfig.logError('Statistics load error', e);
    }
    setState(() { _loading = false; });
  }

  Future<void> _loadAnalytics() async {
    try {
      // Simulate loading usage trends (in real app, this would come from API)
      _usageTrendData = _generateUsageTrendData();
      _maintenanceTrendData = _generateMaintenanceTrendData();
      
      // Calculate monthly aggregates
      _calculateMonthlyData();
      
    } catch (e) {
      AppConfig.logError('Analytics load error', e);
    }
  }

  List<FlSpot> _generateUsageTrendData() {
    // Simulate 6 months of usage data
    final data = <FlSpot>[];
    
    for (int i = 5; i >= 0; i--) {
      final hours = 100 + (i * 20) + (i % 2 == 0 ? 30 : -10); // Simulate varying usage
      data.add(FlSpot(i.toDouble(), hours.toDouble()));
    }
    
    return data;
  }

  List<FlSpot> _generateMaintenanceTrendData() {
    // Simulate 6 months of maintenance data
    final data = <FlSpot>[];
    
    for (int i = 5; i >= 0; i--) {
      final count = 2 + (i % 3); // Simulate 2-4 maintenance items per month
      data.add(FlSpot(i.toDouble(), count.toDouble()));
    }
    
    return data;
  }

  void _calculateMonthlyData() {
    final now = DateTime.now();
    
    // Calculate monthly usage
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM').format(month);
      _monthlyUsage[monthName] = 100 + (i * 20) + (i % 2 == 0 ? 30 : -10);
    }
    
    // Calculate monthly maintenance
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM').format(month);
      _monthlyMaintenance[monthName] = 2 + (i % 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Statistics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: \\$_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTractorStats(context),
                        const SizedBox(height: 24),
                        _buildTimeRangeSelector(),
                        const SizedBox(height: 24),
                        _buildUsageTrendChart(),
                        const SizedBox(height: 24),
                        _buildMaintenanceTrendChart(),
                        const SizedBox(height: 24),
                        _buildInsightsCards(),
                        const SizedBox(height: 24),
                        _buildMaintenanceStats(context),
                        const SizedBox(height: 24),
                        _buildAudioStats(context),
                        const SizedBox(height: 24),
                        _buildUsageStats(context),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTractorStats(BuildContext context) {
    return Consumer<TractorProvider>(
      builder: (context, provider, _) {
        final total = provider.tractors.length;
        final goods = provider.getGoodTractors().length;
        final warns = provider.getWarningTractors().length;
        final crits = provider.getCriticalTractors().length;
        if (total == 0) {
          return _emptyCard('No tractors found for analysis.', icon: Icons.agriculture);
        }
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tractor Health Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          color: Colors.green,
                          value: goods.toDouble(),
                          title: 'Good\\n$goods',
                          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.orange,
                          value: warns.toDouble(),
                          title: 'Warning\\n$warns',
                          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: Colors.red,
                          value: crits.toDouble(),
                          title: 'Critical\\n$crits',
                          titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statBadge(Icons.agriculture, total, 'Total', color: Colors.blue.shade700),
                    const SizedBox(width: 14),
                    _statBadge(Icons.thumb_up, goods, 'Good', color: Colors.green),
                    const SizedBox(width: 14),
                    _statBadge(Icons.warning, warns, 'Warning', color: Colors.orange),
                    const SizedBox(width: 14),
                    _statBadge(Icons.error, crits, 'Critical', color: Colors.red),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceStats(BuildContext context) {
    if (_stats == null) {
      return _emptyCard('No maintenance statistics available.', icon: Icons.build);
    }
    
    final totalRecords = _stats!['total_maintenance_records'] ?? 0;
    final recordsWithCost = _stats!['records_with_cost'] ?? 0;
    final totalSpent = _stats!['total_spent_rwf'] ?? 0;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maintenance Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            Row(
              children: [
                _statBadge(Icons.build, totalRecords, 'Total Records', color: Colors.blue.shade700),
                const SizedBox(width: 14),
                _statBadge(Icons.receipt, recordsWithCost, 'With Cost', color: Colors.orange),
                const SizedBox(width: 14),
                if (totalSpent > 0)
                  _statBadge(Icons.monetization_on, totalSpent, 'Total Spent', color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioStats(BuildContext context) {
    // Audio stats will be shown via AudioProvider in the future
    // For now, show a placeholder that can be enhanced
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Audio Test Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.graphic_eq, color: Colors.blue),
                SizedBox(width: 8),
                Text('Audio test statistics will be displayed here'),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/tractors'),
              icon: const Icon(Icons.agriculture),
              label: const Text('View Tractors to Run Tests'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStats(BuildContext context) {
    // Usage stats are per-tractor, shown in tractor detail
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Usage Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Detailed usage statistics are available in each tractor\'s detail screen'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/tractors'),
              icon: const Icon(Icons.agriculture),
              label: const Text('View Tractors for Usage Details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String message, {IconData? icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Column(
          children: [
            if (icon != null) Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 18),
            Text(message, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(IconData icon, dynamic value, String label, {Color? color}) {
    final c = color ?? Colors.blue;
    return Container(
      width: 62,
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 4),
          Text('$value', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: c), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(fontSize: 11, color: c), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analytics Period',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Row(
              children: ['1M', '3M', '6M', '1Y'].map((period) => 
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildTimeRangeButton(period),
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButton(String period) {
    final isSelected = _selectedTimeRange == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeRange = period;
        });
        _loadAnalytics(); // Reload data for new time range
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          period,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildUsageTrendChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Usage Trends',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Hours/Month',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}h',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final months = ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          final index = value.toInt();
                          if (index >= 0 && index < months.length) {
                            return Text(months[index], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _usageTrendData,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceTrendChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Maintenance Trends',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tasks/Month',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 5,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final months = ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          final index = value.toInt();
                          if (index >= 0 && index < months.length) {
                            return Text(months[index], style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: _maintenanceTrendData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final spot = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: spot.y,
                          color: Colors.orange,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Insights',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                icon: Icons.trending_up,
                title: 'Usage Trend',
                value: '+12%',
                description: 'vs last month',
                color: Colors.green,
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                icon: Icons.schedule,
                title: 'Avg. Hours/Day',
                value: '8.5h',
                description: 'across fleet',
                color: Colors.blue,
                isPositive: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                icon: Icons.warning,
                title: 'Maintenance Due',
                value: '3',
                description: 'this week',
                color: Colors.orange,
                isPositive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                icon: Icons.savings,
                title: 'Cost Savings',
                value: '\$2.4k',
                description: 'preventive maintenance',
                color: Colors.green,
                isPositive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color color,
    bool? isPositive,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                if (isPositive != null)
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
