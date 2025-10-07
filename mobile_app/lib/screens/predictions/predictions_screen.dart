import 'package:flutter/material.dart';
import '../../config/theme.dart';

class PredictionsScreen extends StatelessWidget {
  final String tractorId;

  const PredictionsScreen({Key? key, required this.tractorId})
      : super(key: key);

  // Mock predictions data
  final List<Map<String, dynamic>> predictions = const [
    {
      'task': 'Oil Change',
      'status': 'overdue',
      'hours_remaining': -20,
      'days_remaining': -3,
      'cost': 50000,
      'priority': 'critical',
    },
    {
      'task': 'Air Filter Replacement',
      'status': 'due_soon',
      'hours_remaining': 45,
      'days_remaining': 7,
      'cost': 35000,
      'priority': 'high',
    },
    {
      'task': 'Tire Inspection',
      'status': 'upcoming',
      'hours_remaining': 120,
      'days_remaining': 18,
      'cost': 0,
      'priority': 'medium',
    },
    {
      'task': 'Hydraulic Fluid Check',
      'status': 'due_soon',
      'hours_remaining': 80,
      'days_remaining': 12,
      'cost': 75000,
      'priority': 'high',
    },
  ];

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return AppTheme.criticalRed;
      case 'high':
        return AppTheme.warningYellow;
      case 'medium':
        return AppTheme.accentOrange;
      default:
        return AppTheme.neutralGray;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Alerts'),
      ),
      body: Column(
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.criticalRed.withOpacity(0.1),
            child: Row(
              children: [
                Icon(Icons.error, color: AppTheme.criticalRed, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Action Required',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '1 overdue task, 2 tasks due soon',
                        style: TextStyle(color: AppTheme.neutralGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Predictions list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final pred = predictions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getPriorityIcon(pred['priority']),
                              color: _getPriorityColor(pred['priority']),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pred['task'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(pred['priority'])
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pred['priority'].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(pred['priority']),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 16, color: AppTheme.neutralGray),
                            const SizedBox(width: 4),
                            Text(
                              pred['hours_remaining'] < 0
                                  ? '${pred['hours_remaining'].abs()} hours overdue'
                                  : '${pred['hours_remaining']} hours remaining',
                              style: TextStyle(
                                color: pred['hours_remaining'] < 0
                                    ? AppTheme.criticalRed
                                    : AppTheme.neutralGray,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.calendar_today,
                                size: 16, color: AppTheme.neutralGray),
                            const SizedBox(width: 4),
                            Text(
                              pred['days_remaining'] < 0
                                  ? '${pred['days_remaining'].abs()} days overdue'
                                  : '${pred['days_remaining']} days',
                              style: TextStyle(color: AppTheme.neutralGray),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Est. Cost: ${pred['cost']} RWF',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Schedule'),
                            ),
                          ],
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
}