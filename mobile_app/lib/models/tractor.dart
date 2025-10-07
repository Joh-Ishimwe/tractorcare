class Tractor {
  final String tractorId;
  final String coopId;
  final String model;
  final double engineHours;
  final String usageIntensity;
  final String currentStatus;
  final DateTime? lastMaintenanceDate;
  
  Tractor({
    required this.tractorId,
    required this.coopId,
    required this.model,
    required this.engineHours,
    required this.usageIntensity,
    required this.currentStatus,
    this.lastMaintenanceDate,
  });
  
  factory Tractor.fromJson(Map<String, dynamic> json) {
    return Tractor(
      tractorId: json['tractor_id'],
      coopId: json['coop_id'],
      model: json['model'],
      engineHours: json['engine_hours'].toDouble(),
      usageIntensity: json['usage_intensity'],
      currentStatus: json['current_status'],
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.parse(json['last_maintenance_date'])
          : null,
    );
  }
  
  Map<String, dynamic> toLocalDb() {
    return {
      'tractor_id': tractorId,
      'coop_id': coopId,
      'model': model,
      'engine_hours': engineHours,
      'usage_intensity': usageIntensity,
      'current_status': currentStatus,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
    };
  }
  
  factory Tractor.fromLocalDb(Map<String, dynamic> map) {
    return Tractor(
      tractorId: map['tractor_id'],
      coopId: map['coop_id'],
      model: map['model'],
      engineHours: map['engine_hours'],
      usageIntensity: map['usage_intensity'],
      currentStatus: map['current_status'],
      lastMaintenanceDate: map['last_maintenance_date'] != null
          ? DateTime.parse(map['last_maintenance_date'])
          : null,
    );
  }
}