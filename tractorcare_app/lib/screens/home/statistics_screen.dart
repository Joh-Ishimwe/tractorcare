import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../providers/audio_provider.dart';
import '../../services/api_service.dart';
import '../../config/colors.dart';
import '../../models/audio_prediction.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  String? _error;
  final ApiService _apiService = ApiService();
  
  // Maintenance stats
  Map<String, int> _maintenanceStats = {
    'total': 0,
    'upcoming': 0,
    'completed': 0,
    'overdue': 0,
  };
  
  // Audio stats
  Map<String, int> _audioStats = {
    'total': 0,
    'normal': 0,
    'abnormal': 0,
    'unknown': 0,
  };
  
  // Usage stats
  Map<String, dynamic>? _usageStats;

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
      final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      
      // Fetch tractors
      await tractorProvider.fetchTractors();
      
      // Fetch maintenance stats for all tractors
      await _loadMaintenanceStats(tractorProvider.tractors);
      
      // Fetch audio stats for all tractors
      await _loadAudioStats(tractorProvider.tractors, audioProvider);
      
      // Fetch usage stats (aggregate from first tractor if available)
      if (tractorProvider.tractors.isNotEmpty) {
        try {
          // Use tractor_id (like "T005") not database id
          _usageStats = await _apiService.getUsageStats(tractorProvider.tractors.first.tractorId);
        } catch (e) {
          print('Error loading usage stats: $e');
        }
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
    setState(() { _loading = false; });
  }
  
  Future<void> _loadMaintenanceStats(List tractors) async {
    int total = 0, upcoming = 0, completed = 0, overdue = 0;
    
    for (var tractor in tractors) {
      try {
        // Use tractor_id (like "T005") not database id
        final upcomingTasks = await _apiService.getMaintenance(tractor.tractorId, completed: false);
        final completedTasks = await _apiService.getMaintenance(tractor.tractorId, completed: true);
        
        total += upcomingTasks.length + completedTasks.length;
        upcoming += upcomingTasks.length;
        completed += completedTasks.length;
        
        // Count overdue
        final now = DateTime.now();
        overdue += upcomingTasks.where((task) {
          return task.dueDate.isBefore(now);
        }).length;
      } catch (e) {
        print('Error loading maintenance for ${tractor.tractorId}: $e');
      }
    }
    
    setState(() {
      _maintenanceStats = {
        'total': total,
        'upcoming': upcoming,
        'completed': completed,
        'overdue': overdue,
      };
    });
  }
  
  Future<void> _loadAudioStats(List tractors, AudioProvider audioProvider) async {
    int total = 0, normal = 0, abnormal = 0, unknown = 0;
    
    for (var tractor in tractors) {
      try {
        // Use tractor_id (like "T005") not database id
        await audioProvider.fetchPredictions(tractor.tractorId);
        final predictions = audioProvider.predictions;
        
        total += predictions.length;
        normal += predictions.where((p) => p.predictionClass == PredictionClass.normal).length;
        abnormal += predictions.where((p) => p.predictionClass == PredictionClass.abnormal).length;
        unknown += predictions.where((p) => p.predictionClass == PredictionClass.unknown).length;
      } catch (e) {
        print('Error loading audio stats for ${tractor.tractorId}: $e');
      }
    }
    
    setState(() {
      _audioStats = {
        'total': total,
        'normal': normal,
        'abnormal': abnormal,
        'unknown': unknown,
      };
    });
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
    if (_maintenanceStats['total'] == 0) {
      return _emptyCard('No maintenance data available.', icon: Icons.build);
    }
    
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
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.green,
                      value: _maintenanceStats['completed']!.toDouble(),
                      title: 'Done\n${_maintenanceStats['completed']}',
                      titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                    ),
                    PieChartSectionData(
                      color: Colors.orange,
                      value: (_maintenanceStats['upcoming']! - _maintenanceStats['overdue']!).toDouble(),
                      title: 'Due\n${_maintenanceStats['upcoming']! - _maintenanceStats['overdue']!}',
                      titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                    ),
                    if (_maintenanceStats['overdue']! > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: _maintenanceStats['overdue']!.toDouble(),
                        title: 'Overdue\n${_maintenanceStats['overdue']}',
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
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
                _statBadge(Icons.build, _maintenanceStats['total']!, 'Total', color: Colors.blue.shade700),
                const SizedBox(width: 14),
                _statBadge(Icons.check_circle, _maintenanceStats['completed']!, 'Done', color: Colors.green),
                const SizedBox(width: 14),
                _statBadge(Icons.schedule, _maintenanceStats['upcoming']!, 'Upcoming', color: Colors.orange),
                if (_maintenanceStats['overdue']! > 0) ...[
                  const SizedBox(width: 14),
                  _statBadge(Icons.error, _maintenanceStats['overdue']!, 'Overdue', color: Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioStats(BuildContext context) {
    if (_audioStats['total'] == 0) {
      return _emptyCard('No audio test results available.', icon: Icons.graphic_eq);
    }
    
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
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (_audioStats['normal']! > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: _audioStats['normal']!.toDouble(),
                        title: 'Normal\n${_audioStats['normal']}',
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                      ),
                    if (_audioStats['abnormal']! > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: _audioStats['abnormal']!.toDouble(),
                        title: 'Abnormal\n${_audioStats['abnormal']}',
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                      ),
                    if (_audioStats['unknown']! > 0)
                      PieChartSectionData(
                        color: Colors.grey,
                        value: _audioStats['unknown']!.toDouble(),
                        title: 'Unknown\n${_audioStats['unknown']}',
                        titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
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
                _statBadge(Icons.graphic_eq, _audioStats['total']!, 'Total', color: Colors.blue.shade700),
                const SizedBox(width: 14),
                _statBadge(Icons.check_circle, _audioStats['normal']!, 'Normal', color: Colors.green),
                const SizedBox(width: 14),
                _statBadge(Icons.warning, _audioStats['abnormal']!, 'Abnormal', color: Colors.red),
                if (_audioStats['unknown']! > 0) ...[
                  const SizedBox(width: 14),
                  _statBadge(Icons.help_outline, _audioStats['unknown']!, 'Unknown', color: Colors.grey),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStats(BuildContext context) {
    if (_usageStats == null) {
      return _emptyCard('No usage statistics available.', icon: Icons.bar_chart);
    }
    
    final last7Days = _usageStats!['usage_last_7_days'] ?? {};
    final last30Days = _usageStats!['usage_last_30_days'] ?? {};
    final total7 = (last7Days['total_hours'] ?? 0).toDouble();
    final total30 = (last30Days['total_hours'] ?? 0).toDouble();
    final avg7 = (last7Days['average_per_day'] ?? 0).toDouble();
    
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBadge(Icons.access_time, total7.toInt(), 'Last 7 Days', color: Colors.blue.shade700),
                const SizedBox(width: 14),
                _statBadge(Icons.calendar_month, total30.toInt(), 'Last 30 Days', color: Colors.green),
                const SizedBox(width: 14),
                _statBadge(Icons.trending_up, avg7.toInt(), 'Avg/Day', color: Colors.orange),
              ],
            ),
            if (total7 > 0 || total30 > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Last 7 days: ${total7.toStringAsFixed(1)}h | Last 30 days: ${total30.toStringAsFixed(1)}h',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
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

  Widget _statBadge(IconData icon, int value, String label, {Color? color}) {
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
          Text('$value', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: c)),
          Text(label, style: TextStyle(fontSize: 11, color: c)),
        ],
      ),
    );
  }
}
