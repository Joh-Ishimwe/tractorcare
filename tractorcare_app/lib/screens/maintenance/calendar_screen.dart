// lib/screens/maintenance/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/tractor_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../config/colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final PageController _pageController = PageController();

  // Mock events: {DateTime: List<String>} → List of tractor IDs
  final Map<DateTime, List<String>> _events = {};

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
    final provider = Provider.of<TractorProvider>(context, listen: false);
    // TODO: Replace with real API call to fetch maintenance schedule
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate API

    setState(() {
      _events.clear();
      final tractors = provider.tractors.map((t) => t.tractorId).toList();

      // Mock: Assign random tractors to dates in November 2025
      final dates = [
        DateTime(2025, 11, 4),
        DateTime(2025, 11, 5),
        DateTime(2025, 11, 8),
        DateTime(2025, 11, 12),
        DateTime(2025, 11, 15),
        DateTime(2025, 11, 19),
        DateTime(2025, 11, 22),
        DateTime(2025, 11, 25),
        DateTime(2025, 11, 28),
      ];

      for (var date in dates) {
        final count = 1 + (date.day % 3); // 1–3 tractors per day
        final shuffled = (tractors..shuffle()).take(count).toList();
        _events[DateTime(date.year, date.month, date.day)] = shuffled;
      }
    });
  }

  void _showScheduleBottomSheet() {
    final provider = Provider.of<TractorProvider>(context, listen: false);
    final tractors = provider.tractors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
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
                onChanged: (value) {},
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
                decoration: const InputDecoration(
                  labelText: 'Notes (e.g., Oil Change)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Save to API
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Maintenance scheduled!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Schedule', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
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
    final firstWeekday = firstDayOfMonth.weekday;
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
                final week = index ~/ 7;
                final dayOfWeek = index % 7;
                
                // Calculate the actual date for this cell
                final dayNumber = (week * 7 + dayOfWeek) - (firstWeekday % 7) + 1;
                
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
                          ? AppColors.primary.withValues(alpha: 0.2)
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
                            children: events.take(3).map((event) => Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Maintenance Calendar'),
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        child: Column(
          children: [
            // Header + Schedule Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Schedule and track maintenance activities',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showScheduleBottomSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Schedule Maintenance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
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
                    Text(
                      'Events on ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...(_getEventsForDay(_selectedDay!).map((event) => 
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text('Tractor: $event', style: const TextStyle(fontSize: 14)),
                      )
                    ).toList()),
                    if (_getEventsForDay(_selectedDay!).isEmpty)
                      const Text(
                        'No maintenance scheduled for this day',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}