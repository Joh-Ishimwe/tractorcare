// lib/models/dashboard_stats.dart

class DashboardStats {
  final int totalTractors;
  final int totalAlerts;
  final int urgentAlerts;
  final int scheduledMaintenance;
  final int completedMaintenance;

  DashboardStats({
    this.totalTractors = 0,
    this.totalAlerts = 0,
    this.urgentAlerts = 0,
    this.scheduledMaintenance = 0,
    this.completedMaintenance = 0,
  });

  DashboardStats copyWith({
    int? totalTractors,
    int? totalAlerts,
    int? urgentAlerts,
    int? scheduledMaintenance,
    int? completedMaintenance,
  }) {
    return DashboardStats(
      totalTractors: totalTractors ?? this.totalTractors,
      totalAlerts: totalAlerts ?? this.totalAlerts,
      urgentAlerts: urgentAlerts ?? this.urgentAlerts,
      scheduledMaintenance: scheduledMaintenance ?? this.scheduledMaintenance,
      completedMaintenance: completedMaintenance ?? this.completedMaintenance,
    );
  }
}
