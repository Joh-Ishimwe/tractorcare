class MaintenancePrediction {
  final String taskName;
  final String description;
  final String status;
  final int urgencyLevel;
  final String priority;
  final double hoursRemaining;
  final int daysRemaining;
  final int estimatedCostRwf;
  final String recommendation;
  
  MaintenancePrediction({
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
  
  factory MaintenancePrediction.fromJson(Map<String, dynamic> json) {
    return MaintenancePrediction(
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
  
  bool get isUrgent => status == 'overdue' || status == 'urgent';
  bool get needsAttention => isUrgent || status == 'due_soon';
}