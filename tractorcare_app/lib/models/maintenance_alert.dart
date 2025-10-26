// lib/models/maintenance_alert.dart

class MaintenanceAlert {
  final String id;
  final String tractorId;
  final String alertType;
  final String priority;
  final String title;
  final String description;
  final double hoursRemaining;
  final double estimatedCost;
  final String status;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? completedAt;

  MaintenanceAlert({
    required this.id,
    required this.tractorId,
    required this.alertType,
    required this.priority,
    required this.title,
    required this.description,
    required this.hoursRemaining,
    required this.estimatedCost,
    this.status = 'pending',
    this.dueDate,
    this.createdAt,
    this.completedAt,
  });

  factory MaintenanceAlert.fromJson(Map<String, dynamic> json) {
    return MaintenanceAlert(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      alertType: json['alert_type'] ?? '',
      priority: json['priority'] ?? 'medium',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      hoursRemaining: (json['hours_remaining'] ?? 0).toDouble(),
      estimatedCost: (json['estimated_cost'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tractor_id': tractorId,
      'alert_type': alertType,
      'priority': priority,
      'title': title,
      'description': description,
      'hours_remaining': hoursRemaining,
      'estimated_cost': estimatedCost,
      'status': status,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  // Get priority display name
  String get displayPriority {
    switch (priority.toLowerCase()) {
      case 'critical':
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return priority;
    }
  }

  // Get priority color code
  String get priorityColor {
    switch (priority.toLowerCase()) {
      case 'critical':
      case 'urgent':
        return 'error';
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      case 'low':
        return 'success';
      default:
        return 'info';
    }
  }

  // Get status display name
  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'overdue':
        return 'Overdue';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Check if alert is overdue
  bool get isOverdue {
    if (dueDate == null) return hoursRemaining < 0;
    return DateTime.now().isAfter(dueDate!);
  }

  // Check if alert is due soon (within 50 hours)
  bool get isDueSoon {
    return hoursRemaining <= 50 && hoursRemaining > 0;
  }

  // Get formatted cost in RWF
  String get formattedCost {
    return '${estimatedCost.toStringAsFixed(0)} RWF';
  }

  // Get time remaining text
  String get timeRemainingText {
    if (isOverdue) return 'Overdue!';
    if (hoursRemaining < 0) return 'Overdue!';
    if (hoursRemaining < 1) return 'Due now';
    return '${hoursRemaining.toStringAsFixed(0)} hours';
  }

  // Get alert icon based on type
  String get iconName {
    switch (alertType.toLowerCase()) {
      case 'oil_change':
        return 'oil_barrel';
      case 'filter_replace':
        return 'filter_alt';
      case 'inspection':
        return 'search';
      case 'repair':
        return 'build';
      case 'service':
        return 'construction';
      default:
        return 'notifications';
    }
  }

  // Copy with method
  MaintenanceAlert copyWith({
    String? id,
    String? tractorId,
    String? alertType,
    String? priority,
    String? title,
    String? description,
    double? hoursRemaining,
    double? estimatedCost,
    String? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return MaintenanceAlert(
      id: id ?? this.id,
      tractorId: tractorId ?? this.tractorId,
      alertType: alertType ?? this.alertType,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      hoursRemaining: hoursRemaining ?? this.hoursRemaining,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
