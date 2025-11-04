// lib/models/tractor_summary.dart

class TractorSummary {
  final String tractorId;
  final String model;
  final double engineHours;
  final int healthScore;
  final String healthStatus;
  final int totalAlerts;
  final int criticalAlerts;
  final int highPriorityAlerts;
  final int overdueAlerts;
  final int totalEstimatedTimeMinutes;
  final double totalEstimatedTimeHours;
  final double totalSpentRwf;
  final int maintenanceRecordsCount;
  final int recentAnomalyCount;
  final DateTime? lastMaintenanceDate;
  final String? costNote;
  final List<MaintenanceAlert> alerts;

  TractorSummary({
    required this.tractorId,
    required this.model,
    required this.engineHours,
    required this.healthScore,
    required this.healthStatus,
    required this.totalAlerts,
    required this.criticalAlerts,
    required this.highPriorityAlerts,
    required this.overdueAlerts,
    required this.totalEstimatedTimeMinutes,
    required this.totalEstimatedTimeHours,
    required this.totalSpentRwf,
    required this.maintenanceRecordsCount,
    required this.recentAnomalyCount,
    this.lastMaintenanceDate,
    this.costNote,
    required this.alerts,
  });

  factory TractorSummary.fromJson(Map<String, dynamic> json) {
    return TractorSummary(
      tractorId: json['tractor_id'] ?? '',
      model: json['model'] ?? '',
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      healthScore: json['health_score'] ?? 0,
      healthStatus: json['health_status'] ?? '',
      totalAlerts: json['total_alerts'] ?? 0,
      criticalAlerts: json['critical_alerts'] ?? 0,
      highPriorityAlerts: json['high_priority_alerts'] ?? 0,
      overdueAlerts: json['overdue_alerts'] ?? 0,
      totalEstimatedTimeMinutes: json['total_estimated_time_minutes'] ?? 0,
      totalEstimatedTimeHours: (json['total_estimated_time_hours'] ?? 0).toDouble(),
      totalSpentRwf: (json['total_spent_rwf'] ?? 0).toDouble(),
      maintenanceRecordsCount: json['maintenance_records_count'] ?? 0,
      recentAnomalyCount: json['recent_anomaly_count'] ?? 0,
      lastMaintenanceDate: json['last_maintenance_date'] != null 
          ? DateTime.parse(json['last_maintenance_date']) 
          : null,
      costNote: json['cost_note'],
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((alert) => MaintenanceAlert.fromJson(alert))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tractor_id': tractorId,
      'model': model,
      'engine_hours': engineHours,
      'health_score': healthScore,
      'health_status': healthStatus,
      'total_alerts': totalAlerts,
      'critical_alerts': criticalAlerts,
      'high_priority_alerts': highPriorityAlerts,
      'overdue_alerts': overdueAlerts,
      'total_estimated_time_minutes': totalEstimatedTimeMinutes,
      'total_estimated_time_hours': totalEstimatedTimeHours,
      'total_spent_rwf': totalSpentRwf,
      'maintenance_records_count': maintenanceRecordsCount,
      'recent_anomaly_count': recentAnomalyCount,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'cost_note': costNote,
      'alerts': alerts.map((alert) => alert.toJson()).toList(),
    };
  }
}

class MaintenanceAlert {
  final String id;
  final String type;
  final String priority;
  final String message;
  final DateTime? dueDate;
  final bool overdue;

  MaintenanceAlert({
    required this.id,
    required this.type,
    required this.priority,
    required this.message,
    this.dueDate,
    required this.overdue,
  });

  factory MaintenanceAlert.fromJson(Map<String, dynamic> json) {
    return MaintenanceAlert(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      priority: json['priority'] ?? '',
      message: json['message'] ?? '',
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date']) 
          : null,
      overdue: json['overdue'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'priority': priority,
      'message': message,
      'due_date': dueDate?.toIso8601String(),
      'overdue': overdue,
    };
  }
}