import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
// Import other providers as needed for maintenance, audio, usage.

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _loading = true;
  String? _error;

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
      // Imagine calling Provider methods for tractors, maintenance, etc. here.
      // await Provider.of<TractorProvider>(context, listen: false).fetchTractors();
      // Also for maintenance, audio, and usage providers as needed.
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
    setState(() { _loading = false; });
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
    // Placeholder - can integrate MaintenanceProvider for breakdown (due/completed/overdue)
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
            Row(children: [
               Icon(Icons.build, color: Colors.orange),
               SizedBox(width: 8),
               Text('Maintenance stats go here'),
            ]),
            // TODO: Add real chart once MaintenanceProvider is integrated
          ],
        ),
      ),
    );
  }

  Widget _buildAudioStats(BuildContext context) {
    // Placeholder - can integrate AudioProvider
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
            Row(children: [
               Icon(Icons.graphic_eq, color: Colors.blue),
               SizedBox(width: 8),
               Text('Audio stats go here'),
            ]),
            // TODO: Add real chart once AudioProvider is integrated
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStats(BuildContext context) {
    // Placeholder - can integrate UsageProvider
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
            Row(children: [
               Icon(Icons.bar_chart, color: Colors.green),
               SizedBox(width: 8),
               Text('Usage stats go here'),
            ]),
            // TODO: Add real chart once UsageProvider is integrated
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
