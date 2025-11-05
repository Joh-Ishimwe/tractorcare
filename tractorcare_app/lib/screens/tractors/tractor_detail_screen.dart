// lib/screens/tractors/tractor_detail_screen.dart

// import 'dart:math' as math;
// import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tractorId == null) {
      _tractorId = ModalRoute.of(context)!.settings.arguments as String;
      
      print('🔍 Tractor Detail Screen: Received ID: $_tractorId');
      print('   - Length: ${_tractorId!.length}');
      print('   - Is ObjectID format (24 hex chars): ${_tractorId!.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_tractorId!)}');
      print('   - Is TractorID format (starts with T): ${_tractorId!.startsWith('T')}');
      
      if (_tractorId!.length == 24 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_tractorId!)) {
        print('⚠️ WARNING: Received ObjectID format, this will cause 404 errors!');
        print('   Expected format: T007, T001, etc.');
      }
      
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
    
    // Load maintenance summary (removed - now showing static next maintenance)
    
    setState(() => _isLoading = false);
  }

  // Helper method to safely parse double values that might come as strings
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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

                        const SizedBox(height: 16),

                        // Quick Actions 
                        _buildQuickActions(tractor),

                        const SizedBox(height: 24),

                        // Info Card
                        _buildInfoCard(tractor),

                        const SizedBox(height: 16),

                        // Maintenance alerts
                        _buildMaintenanceAlertsCard(),

                        const SizedBox(height: 16),

                        // Usage History
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.successGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tractor Icon - larger and more prominent
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.agriculture,
                  color: AppColors.success,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 24),
            
            // Tractor Info - centered section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tractor.model,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tractor.tractorId,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status and Baseline - horizontal layout as shown in image
            Row(
              children: [
                // Status Section
                Column(
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                
                // Baseline Section
                Column(
                  children: [
                    const Text(
                      'Baseline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
              'Tractors Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (tractor.purchaseYear != null) ...[
              Text(
                'Purchased Year: ${tractor.purchaseYear}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Total Engine Hours: ${tractor.formattedEngineHours}',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildQuickActions(Tractor tractor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.mic,
              label: 'Test Audio',
              color: AppColors.success,
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
            child: _buildCompactActionButton(
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildCompactActionButton(
              icon: Icons.graphic_eq,
              label: 'Baseline',
              color: AppColors.info,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/baseline-collection',
                  arguments: {
                    'tractorId': tractor.tractorId,
                    'tractorHours': tractor.engineHours,
                    'model': tractor.model,
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Maintenance Summary (grid of stats)

  Widget _buildMaintenanceAlertsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Maintenance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildNextMaintenanceItem(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextMaintenanceItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Engine oil and filter change',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '20h or 70 remaining',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
                    // Safely parse numeric values that might come as strings
                    final hoursUsed = _parseDouble(record['hours_used']) ?? 0.0;
                    final endHours = _parseDouble(record['end_hours']) ?? 0.0;
                    
                    return ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text('${hoursUsed.toStringAsFixed(1)} hours used'),
                      trailing: Text(
                        '${endHours.toStringAsFixed(0)} hrs',
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

}