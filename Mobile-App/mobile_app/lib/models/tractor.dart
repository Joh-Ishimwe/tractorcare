// lib/models/tractor.dart

class Tractor {
  final String tractorId;
  final String model;
  final double engineHours;
  final String usageIntensity;
  final DateTime purchaseDate;
  final String healthStatus;

  Tractor({
    required this.tractorId,
    required this.model,
    required this.engineHours,
    required this.usageIntensity,
    required this.purchaseDate,
    required this.healthStatus,
  });

  factory Tractor.fromJson(Map<String, dynamic> json) {
    return Tractor(
      tractorId: json['tractor_id'],
      model: json['model'],
      engineHours: json['engine_hours'].toDouble(),
      usageIntensity: json['usage_intensity'],
      purchaseDate: DateTime.parse(json['purchase_date']),
      healthStatus: json['health_status'] ?? 'healthy',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tractor_id': tractorId,
      'model': model,
      'engine_hours': engineHours,
      'usage_intensity': usageIntensity,
      'purchase_date': purchaseDate.toIso8601String().split('T')[0],
    };
  }
}