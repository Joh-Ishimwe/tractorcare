// lib/screens/tractors/tractor_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../models/tractor.dart';
import '../../config/colors.dart';

class TractorListScreen extends StatefulWidget {
  const TractorListScreen({Key? key}) : super(key: key);

  @override
  State<TractorListScreen> createState() => _TractorListScreenState();
}

class _TractorListScreenState extends State<TractorListScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTractors();
  }

  Future<void> _loadTractors() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    await tractorProvider.fetchTractors();
  }

  List<Tractor> _filterTractors(List<Tractor> tractors) {
    return tractors.where((tractor) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          tractor.tractorId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tractor.model.toLowerCase().contains(_searchQuery.toLowerCase());

      // Status filter
      final matchesStatus = _filterStatus == 'all' ||
          tractor.status.name == _filterStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Tractors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search tractors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Good', 'good'),
                const SizedBox(width: 8),
                _buildFilterChip('Warning', 'warning'),
                const SizedBox(width: 8),
                _buildFilterChip('Critical', 'critical'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tractor List
          Expanded(
            child: Consumer<TractorProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.error != null) {
                  return Center(
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
                          'Error loading tractors',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadTractors,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredTractors = _filterTractors(provider.tractors);

                if (filteredTractors.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: _loadTractors,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredTractors.length,
                    itemBuilder: (context, index) {
                      final tractor = filteredTractors[index];
                      return _buildTractorCard(tractor);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/add-tractor').then((_) {
            _loadTractors();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Tractor'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = selected ? value : 'all');
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildTractorCard(Tractor tractor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/tractor-detail',
            arguments: tractor.id,
          ).then((_) {
            _loadTractors();
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Status Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(tractor.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    tractor.statusIcon,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Tractor Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tractor.tractorId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tractor.model,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tractor.formattedEngineHours,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tractor.tractorAge,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(tractor.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tractor.statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(tractor.status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.agriculture_outlined
                  : Icons.search_off,
              size: 80,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No Tractors Yet' : 'No Results Found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Add your first tractor to get started'
                  : 'Try adjusting your search or filters',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/add-tractor');
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Tractor'),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tractors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All Tractors'),
              value: 'all',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Good Condition'),
              value: 'good',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Warning'),
              value: 'warning',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Critical'),
              value: 'critical',
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _filterStatus = 'all');
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(TractorStatus status) {
    switch (status) {
      case TractorStatus.good:
        return AppColors.success;
      case TractorStatus.warning:
        return AppColors.warning;
      case TractorStatus.critical:
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }
}