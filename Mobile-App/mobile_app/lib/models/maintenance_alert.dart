// lib/models/maintenance_alert.dart

class MaintenanceAlert {
  final String taskName;
  final String description;
  final String status; // 'overdue', 'urgent', 'due_soon', 'approaching'
  final int urgencyLevel;
  final String priority;
  final double hoursRemaining;
  final int daysRemaining;
  final int estimatedCostRwf;
  final String recommendation;

  MaintenanceAlert({
    required this.taskName,
    required this.description,
    required this.status,
    required this.urgencyLevel,
    required this.priority,
    required this.hoursRemaining,
    required this.daysRemaining,
    required this.estimatedCostRwf,
    required this.recommendation,
  });

  factory MaintenanceAlert.fromJson(Map<String, dynamic> json) {
    return MaintenanceAlert(
      taskName: json['task_name'],
      description: json['description'],
      status: json['status'],
      urgencyLevel: json['urgency_level'],
      priority: json['priority'],
      hoursRemaining: json['hours_remaining'].toDouble(),
      daysRemaining: json['days_remaining'],
      estimatedCostRwf: json['estimated_cost_rwf'],
      recommendation: json['recommendation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_name': taskName,
      'description': description,
      'status': status,
      'urgency_level': urgencyLevel,
      'priority': priority,
      'hours_remaining': hoursRemaining,
      'days_remaining': daysRemaining,
      'estimated_cost_rwf': estimatedCostRwf,
      'recommendation': recommendation,
    };
  }

  // Get status color name
  String getStatusColor() {
    switch (status) {
      case 'overdue':
        return 'red';
      case 'urgent':
        return 'orange';
      case 'due_soon':
        return 'yellow';
      case 'approaching':
        return 'blue';
      default:
        return 'grey';
    }
  }

  // Get status emoji
  String getStatusEmoji() {
    switch (status) {
      case 'overdue':
        return '🔴';
      case 'urgent':
        return '🟠';
      case 'due_soon':
        return '🟡';
      case 'approaching':
        return '🔵';
      default:
        return '⚪';
    }
  }

  // Get display name for status
  String getStatusDisplayName() {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  // Check if maintenance is critical (overdue or urgent)
  bool get isCritical {
    return status == 'overdue' || status == 'urgent';
  }

  // Check if action is required
  bool get actionRequired {
    return status == 'overdue' || status == 'urgent';
  }

  @override
  String toString() {
    return 'MaintenanceAlert(taskName: $taskName, status: $status, urgency: $urgencyLevel)';
  }
}