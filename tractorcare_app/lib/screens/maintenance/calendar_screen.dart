// lib/screens/maintenance/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/tractor_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/colors.dart';
import '../../config/app_config.dart';
import '../../services/api_service.dart';
import '../../models/maintenance.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final PageController _pageController = PageController();

  // Real maintenance events: {DateTime: List<Maintenance>}
  final Map<DateTime, List<Maintenance>> _maintenanceEvents = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    final apiService = ApiService();
    
    AppConfig.log('Loading maintenance calendar data...');
    
    try {
      await tractorProvider.fetchTractors();
      
      Map<DateTime, List<Maintenance>> events = {};
      
      // Load maintenance tasks for all tractors
      for (final tractor in tractorProvider.tractors) {
        try {
          // Get maintenance alerts (upcoming/overdue tasks)
          final alertsResponse = await apiService.getMaintenanceAlerts(tractor.tractorId);
          final upcomingTasks = alertsResponse.map((alert) => _convertAlertToMaintenance(alert)).toList();
          
          // Get completed maintenance tasks
          final completedTasks = await apiService.getMaintenanceTasks(tractor.tractorId, completed: true);
          
          final allTasks = [...upcomingTasks, ...completedTasks];
          
          AppConfig.log('Loaded ${allTasks.length} maintenance tasks for tractor ${tractor.tractorId}');
          
          // Group tasks by date
          for (final task in allTasks) {
            final dateKey = DateTime(
              task.dueDate.year,
              task.dueDate.month,
              task.dueDate.day,
            );
            
            if (events[dateKey] == null) {
              events[dateKey] = [];
            }
            events[dateKey]!.add(task);
          }
        } catch (e) {
          AppConfig.logError('Failed to load maintenance for tractor ${tractor.tractorId}', e);
          // Continue with other tractors
        }
      }
      
      if (mounted) {
        setState(() {
          _maintenanceEvents.clear();
          _maintenanceEvents.addAll(events);
        });
      }
    } catch (e) {
      AppConfig.logError('Failed to load maintenance calendar data', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load maintenance data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showScheduleBottomSheet() {
    final provider = Provider.of<TractorProvider>(context, listen: false);
    final tractors = provider.tractors;
    
    String? selectedTractorId;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, color: Colors.grey[300]),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Schedule Maintenance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Tractor',
                    border: OutlineInputBorder(),
                  ),
                  items: tractors.map((t) {
                    return DropdownMenuItem(value: t.tractorId, child: Text(t.tractorId));
                  }).toList(),
                  onChanged: (value) {
                    selectedTractorId = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  controller: TextEditingController(
                    text: _selectedDay != null
                        ? '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                        : '',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name (e.g., Oil Change)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      if (selectedTractorId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a tractor')),
                        );
                        return;
                      }
                      
                      if (notesController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a task name')),
                        );
                        return;
                      }
                      
                      setModalState(() => isSubmitting = true);
                      
                      try {
                        final apiService = ApiService();
                        
                        // Create maintenance record
                        await apiService.createMaintenance({
                          'tractor_id': selectedTractorId!,
                          'task_name': notesController.text.trim(),
                          'description': 'Scheduled maintenance task',
                          'completion_date': _selectedDay?.toIso8601String() ?? DateTime.now().toIso8601String(),
                          'completion_hours': 1,
                          'actual_time_minutes': 60,
                          'actual_cost_rwf': 0,
                          'service_location': 'Field',
                          'notes': 'Scheduled from calendar',
                        });
                        
                        Navigator.pop(context);
                        
                        // Refresh calendar data
                        await _loadEvents();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Maintenance scheduled successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to schedule maintenance: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } finally {
                        setModalState(() => isSubmitting = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Schedule', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Maintenance> _getEventsForDay(DateTime day) {
    return _maintenanceEvents[DateTime(day.year, day.month, day.day)] ?? [];
  }



  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final firstWeekday = (firstDayOfMonth.weekday % 7); // Convert Monday=1,Sunday=7 to Sunday=0,Monday=1
    final daysInMonth = lastDayOfMonth.day;

    return Expanded(
      child: Column(
        children: [
          // Days of week header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Calendar grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                // Calculate the actual date for this cell
                final dayNumber = index - firstWeekday + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox(); // Empty cell for days outside current month
                }

                final currentDate = DateTime(_focusedDay.year, _focusedDay.month, dayNumber);
                final isSelected = _isSameDay(currentDate, _selectedDay);
                final isToday = _isSameDay(currentDate, DateTime.now());
                final events = _getEventsForDay(currentDate);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = currentDate;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withOpacity(0.2)
                          : Colors.transparent,
                      border: isToday 
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: isSelected || isToday 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: isSelected || isToday 
                                ? AppColors.primary 
                                : Colors.black,
                          ),
                        ),
                        if (events.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: events.take(3).map((maintenance) {
                              Color indicatorColor;
                              switch (maintenance.status) {
                                case MaintenanceStatus.overdue:
                                  indicatorColor = AppColors.error;
                                  break;
                                case MaintenanceStatus.due:
                                  indicatorColor = AppColors.warning;
                                  break;
                                case MaintenanceStatus.completed:
                                  indicatorColor = AppColors.success;
                                  break;
                                default:
                                  indicatorColor = AppColors.primary;
                              }
                              
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: indicatorColor,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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

  // Convert API alert response to Maintenance object
  Maintenance _convertAlertToMaintenance(Map<String, dynamic> alert) {
    // Parse status from alert status
    MaintenanceStatus status;
    switch (alert['status']?.toString().toLowerCase()) {
      case 'overdue':
        status = MaintenanceStatus.overdue;
        break;
      case 'due':
        status = MaintenanceStatus.due;
        break;
      default:
        status = MaintenanceStatus.upcoming;
    }

    // Parse type from task name
    MaintenanceType type;
    switch (alert['task_name']?.toString().toLowerCase()) {
      case 'engine_oil_change':
      case 'oil_change':
        type = MaintenanceType.oilChange;
        break;
      case 'air_filter_check':
      case 'filter_replacement':
        type = MaintenanceType.filterReplacement;
        break;
      case 'inspection':
        type = MaintenanceType.inspection;
        break;
      case 'service':
        type = MaintenanceType.service;
        break;
      case 'repair':
        type = MaintenanceType.repair;
        break;
      default:
        type = MaintenanceType.other;
    }

    // Parse trigger type from alert data
    MaintenanceTriggerType triggerType;
    switch (alert['trigger_type']?.toString().toLowerCase()) {
      case 'abnormal_sound':
        triggerType = MaintenanceTriggerType.abnormalSound;
        break;
      case 'usage_interval':
        triggerType = MaintenanceTriggerType.usageInterval;
        break;
      case 'manual':
      default:
        triggerType = MaintenanceTriggerType.manual;
    }

    return Maintenance(
      id: alert['id'] ?? '',
      tractorId: alert['tractor_id'] ?? '',
      userId: '', // Default empty since alerts don't have user info
      type: type,
      customType: alert['task_name'] ?? 'general',
      triggerType: triggerType,
      predictionId: alert['prediction_id'],
      dueDate: DateTime.tryParse(alert['due_date'] ?? '') ?? DateTime.now(),
      status: status,
      notes: alert['cost_note'],
      createdAt: DateTime.tryParse(alert['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Maintenance Calendar'),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header + Schedule Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: const Text(
                            'Schedule and track maintenance activities',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showScheduleBottomSheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Schedule'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading maintenance data...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

            // Calendar Header
            _buildCalendarHeader(),

            // Calendar Grid
            _buildCalendarGrid(),

            // Selected day events
            if (_selectedDay != null) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Maintenance on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...(_getEventsForDay(_selectedDay!).map((maintenance) {
                      final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
                      final tractor = tractorProvider.tractors.where(
                        (t) => t.id == maintenance.tractorId,
                      ).firstOrNull;
                      
                      Color statusColor;
                      String statusText;
                      IconData statusIcon;
                      
                      switch (maintenance.status) {
                        case MaintenanceStatus.overdue:
                          statusColor = AppColors.error;
                          statusText = 'OVERDUE';
                          statusIcon = Icons.warning;
                          break;
                        case MaintenanceStatus.due:
                          statusColor = AppColors.warning;
                          statusText = 'DUE';
                          statusIcon = Icons.schedule;
                          break;
                        case MaintenanceStatus.completed:
                          statusColor = AppColors.success;
                          statusText = 'COMPLETED';
                          statusIcon = Icons.check_circle;
                          break;
                        default:
                          statusColor = AppColors.primary;
                          statusText = 'SCHEDULED';
                          statusIcon = Icons.calendar_today;
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(statusIcon, color: statusColor, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    maintenance.customType ?? 'Maintenance',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tractor: ${tractor?.model ?? maintenance.tractorId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (maintenance.notes != null && maintenance.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                maintenance.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList()),
                    if (_getEventsForDay(_selectedDay!).isEmpty && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              color: Colors.grey,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'No maintenance scheduled for this day',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ], // Closes if (_selectedDay != null) ...[
            ], // Closes main Column children
          ),
        ),
      ),
    );
  }
}