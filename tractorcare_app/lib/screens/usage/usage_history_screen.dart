// lib/screens/usage/usage_history_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../config/colors.dart';

class UsageHistoryScreen extends StatefulWidget {
  final String tractorId;

  const UsageHistoryScreen({Key? key, required this.tractorId}) : super(key: key);

  @override
  State<UsageHistoryScreen> createState() => _UsageHistoryScreenState();
}

class _UsageHistoryScreenState extends State<UsageHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  int _selectedDays = 30;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await _apiService.getUsageHistory(
        widget.tractorId,
        days: _selectedDays,
      );
      
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading usage history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Usage History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          PopupMenuButton<int>(
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadHistory();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No usage data available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Bar Chart Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Usage Chart ($_selectedDays days)',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _getMaxHours() * 1.2,
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipColor: (group) => Colors.blueGrey,
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      if (groupIndex < _history.length) {
                                        final record = _history[groupIndex];
                                        final date = DateTime.parse(record['date']);
                                        return BarTooltipItem(
                                          '${date.day}/${date.month}\n${rod.toY.toStringAsFixed(1)}h',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: _getBottomTitles,
                                      reservedSize: 38,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: _getLeftTitles,
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: _getBarGroups(),
                                gridData: const FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // List Section
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final record = _history[index];
                          final date = DateTime.parse(record['date']);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  '${date.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Hours used: ${record['hours_used'].toStringAsFixed(1)}'),
                                  if (record['notes'] != null && record['notes'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        record['notes'],
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${record['end_hours']} hrs',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  double _getMaxHours() {
    if (_history.isEmpty) return 10.0;
    return _history
        .map((record) => (record['hours_used'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  List<BarChartGroupData> _getBarGroups() {
    return _history.asMap().entries.map((entry) {
      final index = entry.key;
      final record = entry.value;
      final hoursUsed = (record['hours_used'] as num).toDouble();
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: hoursUsed,
            color: _getBarColor(hoursUsed),
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  Color _getBarColor(double hours) {
    if (hours >= 8) return Colors.red;
    if (hours >= 6) return Colors.orange;
    if (hours >= 4) return Colors.blue;
    return Colors.lightBlue;
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    if (value.toInt() >= _history.length) return const Text('');
    
    final record = _history[value.toInt()];
    final date = DateTime.parse(record['date']);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${date.day}/${date.month}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _getLeftTitles(double value, TitleMeta meta) {
    return Text(
      '${value.toInt()}h',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}