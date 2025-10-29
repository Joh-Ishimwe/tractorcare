// lib/screens/maintenance/maintenance_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../models/tractor.dart';
import '../../models/maintenance.dart';
import '../../services/api_service.dart';
import '../../config/colors.dart';

class MaintenanceListScreen extends StatefulWidget {
  const MaintenanceListScreen({Key? key}) : super(key: key);

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  
  String? _selectedTractorId;
  List<Maintenance> _upcomingMaintenance = [];
  List<Maintenance> _completedMaintenance = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    await tractorProvider.fetchTractors();
    
    if (tractorProvider.tractors.isNotEmpty && _selectedTractorId == null) {
      setState(() {
        _selectedTractorId = tractorProvider.tractors.first.id;
      });
      await _loadMaintenance();
    }
  }

  Future<void> _loadMaintenance() async {
    if (_selectedTractorId == null) return;

    setState(() => _isLoading = true);

    try {
      final upcoming = await _api.getMaintenance(
        _selectedTractorId!,
        completed: false,
      );
      final completed = await _api.getMaintenance(
        _selectedTractorId!,
        completed: true,
      );

      setState(() {
        _upcomingMaintenance = upcoming;
        _completedMaintenance = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading maintenance: $e'),
            backgroundColor: AppColors.error,
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
        title: const Text('Maintenance'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Upcoming'),
                  if (_upcomingMaintenance.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _upcomingMaintenance.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Completed'),
                  if (_completedMaintenance.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _completedMaintenance.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tractor Selector
          Consumer<TractorProvider>(
            builder: (context, provider, child) {
              if (provider.tractors.isEmpty) {
                return Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'No tractors found',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/add-tractor');
                        },
                        child: const Text('Add Tractor'),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTractorId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: provider.tractors.map((Tractor tractor) {
                      return DropdownMenuItem<String>(
                        value: tractor.id,
                        child: Row(
                          children: [
                            Text(tractor.statusIcon),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${tractor.tractorId} - ${tractor.model}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedTractorId = value);
                      _loadMaintenance();
                    },
                  ),
                ),
              );
            },
          ),

          // Tab View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMaintenanceList(_upcomingMaintenance, false),
                      _buildMaintenanceList(_completedMaintenance, true),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedTractorId == null
            ? null
            : () {
                Navigator.pushNamed(
                  context,
                  '/add-maintenance',
                  arguments: _selectedTractorId,
                ).then((_) => _loadMaintenance());
              },
        icon: const Icon(Icons.add),
        label: const Text('Add Maintenance'),
        backgroundColor: _selectedTractorId == null
            ? AppColors.textDisabled
            : AppColors.primary,
      ),
    );
  }

  Widget _buildMaintenanceList(List<Maintenance> items, bool isCompleted) {
    if (items.isEmpty) {
      return _buildEmptyState(isCompleted);
    }

    return RefreshIndicator(
      onRefresh: _loadMaintenance,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final maintenance = items[index];
          return _buildMaintenanceCard(maintenance, isCompleted);
        },
      ),
    );
  }

  Widget _buildMaintenanceCard(Maintenance maintenance, bool isCompleted) {
    final statusColor = AppColors.getMaintenanceStatusColor(maintenance.status.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/maintenance-detail',
            arguments: maintenance,
          ).then((_) => _loadMaintenance());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      maintenance.typeIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maintenance.typeString,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          maintenance.formattedDueDate,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      maintenance.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        maintenance.isOverdue
                            ? Icons.error
                            : Icons.schedule,
                        size: 16,
                        color: maintenance.isOverdue
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        maintenance.timeUntilDue,
                        style: TextStyle(
                          fontSize: 14,
                          color: maintenance.isOverdue
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: maintenance.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (maintenance.notes != null && maintenance.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  maintenance.notes!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompleted ? Icons.check_circle_outline : Icons.event_note,
              size: 80,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              isCompleted
                  ? 'No Completed Maintenance'
                  : 'No Upcoming Maintenance',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCompleted
                  ? 'Completed maintenance will appear here'
                  : 'Add maintenance schedules to track them',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _selectedTractorId == null
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/add-maintenance',
                          arguments: _selectedTractorId,
                        ).then((_) => _loadMaintenance());
                      },
                icon: const Icon(Icons.add),
                label: const Text('Add Maintenance'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}