// lib/screens/audio/deviation_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/deviation_provider.dart';
import '../../services/offline_sync_service.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';

class DeviationTrackingScreen extends StatefulWidget {
  final String tractorId;
  final String? tractorModel;

  const DeviationTrackingScreen({
    super.key,
    required this.tractorId,
    this.tractorModel,
  });

  @override
  State<DeviationTrackingScreen> createState() => _DeviationTrackingScreenState();
}

class _DeviationTrackingScreenState extends State<DeviationTrackingScreen> {
  OfflineSyncService? _offlineSyncService;

  @override
  void initState() {
    super.initState();
    // Load deviation data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Set up connectivity listener to refresh when connection is restored
    if (_offlineSyncService == null) {
      _offlineSyncService = Provider.of<OfflineSyncService>(context, listen: false);
      _offlineSyncService!.addListener(_onConnectivityChanged);
    }
    
    // Refresh data when screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<DeviationProvider>(context, listen: false);
        // Always refresh when screen becomes visible (in case new predictions were synced)
        if (!provider.isLoading) {
          _loadData();
        }
      }
    });
  }

  @override
  void dispose() {
    _offlineSyncService?.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    // When connection is restored, refresh data in case pending audio was synced
    if (_offlineSyncService?.isOnline == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppConfig.log('📶 Deviation tracking: Connection restored, refreshing data...');
          _loadData();
        }
      });
    }
  }

  void _loadData() {
    final provider = Provider.of<DeviationProvider>(context, listen: false);
    AppConfig.log('🔄 Loading deviation data for tractor: ${widget.tractorId}');
    provider.fetchDeviationData(widget.tractorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.tractorModel != null
              ? 'Deviation Tracking - ${widget.tractorModel}'
              : 'Deviation Tracking',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<DeviationProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading
                    ? null
                    : () {
                        _loadData();
                      },
                tooltip: 'Refresh data',
              );
            },
          ),
        ],
      ),
      body: Consumer<DeviationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        provider.fetchDeviationData(widget.tractorId);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!provider.hasData) {
            return RefreshIndicator(
              onRefresh: () async {
                await provider.fetchDeviationData(widget.tractorId);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.show_chart,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Deviation Data Available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'To see deviation tracking:\n\n1. First, establish a baseline for this tractor\n2. Then record audio tests\n3. The deviation from baseline will be calculated automatically',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _loadData();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchDeviationData(widget.tractorId);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  _buildSummaryCards(provider),
                  
                  const SizedBox(height: 24),
                  
                  // Deviation Chart
                  _buildDeviationChart(provider),
                  
                  const SizedBox(height: 24),
                  
                  // Data Table
                  _buildDataTable(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(DeviationProvider provider) {
    final sortedPoints = provider.sortedDeviationPoints;
    final latestPoint = sortedPoints.isNotEmpty ? sortedPoints.last : null;
    final baselineDate = provider.baselineDate;
    
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Tests',
            '${provider.deviationPoints.length}',
            Icons.assessment,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Deviation',
            provider.averageDeviation.toStringAsFixed(2),
            Icons.trending_up,
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            baselineDate != null ? 'Days Since Baseline' : 'Latest',
            baselineDate != null && latestPoint != null
                ? '${latestPoint.date.difference(baselineDate).inDays}'
                : latestPoint != null
                    ? DateFormat('MM/dd').format(latestPoint.date)
                    : 'N/A',
            Icons.calendar_today,
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviationChart(DeviationProvider provider) {
    final sortedPoints = provider.sortedDeviationPoints;
    if (sortedPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate chart bounds
    final minDev = provider.minDeviation;
    final maxDev = provider.maxDeviation;
    final range = maxDev - minDev;
    final padding = range * 0.1; // 10% padding
    final chartMin = (minDev - padding).clamp(0.0, double.infinity);
    final chartMax = maxDev + padding;

    // Get baseline date for x-axis labels
    final baselineDate = provider.baselineDate ?? sortedPoints.first.date;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deviation from Baseline Over Time',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (chartMax - chartMin) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: value == 0
                          ? AppColors.error.withOpacity(0.5)
                          : AppColors.border.withOpacity(0.2),
                      strokeWidth: value == 0 ? 2 : 1,
                      dashArray: value == 0 ? null : [5, 5],
                    );
                  },
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
                      reservedSize: 30,
                      interval: sortedPoints.length > 10
                          ? (sortedPoints.length / 5).ceil().toDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedPoints.length) {
                          return const Text('');
                        }
                        final point = sortedPoints[index];
                        final daysSince = provider.getDaysSinceBaseline(point.date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Day $daysSince',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: (chartMax - chartMin) / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: sortedPoints.length > 1 ? (sortedPoints.length - 1).toDouble() : 1.0,
                minY: chartMin,
                maxY: chartMax,
                lineBarsData: [
                  // Zero baseline line
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 0),
                      FlSpot(sortedPoints.length > 1 ? (sortedPoints.length - 1).toDouble() : 1.0, 0),
                    ],
                    isCurved: false,
                    color: AppColors.error.withOpacity(0.5),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Deviation line
                  LineChartBarData(
                    spots: sortedPoints.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.deviation,
                      );
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index < 0 || index >= sortedPoints.length) {
                          return null;
                        }
                        final point = sortedPoints[index];
                        final daysSince = provider.getDaysSinceBaseline(point.date);
                        return LineTooltipItem(
                          'Day $daysSince\nDeviation: ${point.deviation.toStringAsFixed(2)}\n${DateFormat('MM/dd/yyyy').format(point.date)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(DeviationProvider provider) {
    final sortedPoints = provider.sortedDeviationPoints;
    final baselineDate = provider.baselineDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Deviation History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedPoints.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final point = sortedPoints[index];
              final daysSince = baselineDate != null
                  ? point.date.difference(baselineDate).inDays
                  : null;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: _getDeviationColor(point.deviation).withOpacity(0.1),
                  child: Icon(
                    Icons.assessment,
                    color: _getDeviationColor(point.deviation),
                    size: 20,
                  ),
                ),
                title: Text(
                  daysSince != null
                      ? 'Day $daysSince'
                      : DateFormat('MM/dd/yyyy').format(point.date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(point.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      point.deviation.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _getDeviationColor(point.deviation),
                      ),
                    ),
                    if (point.engineHours != null)
                      Text(
                        '${point.engineHours!.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getDeviationColor(double deviation) {
    if (deviation < 0.5) {
      return AppColors.success; // Green - very similar
    } else if (deviation < 1.0) {
      return AppColors.warning; // Orange - slightly different
    } else if (deviation < 2.0) {
      return Colors.orange; // Orange - moderately different
    } else {
      return AppColors.error; // Red - very different
    }
  }
}

