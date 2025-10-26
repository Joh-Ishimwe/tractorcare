// lib/models/tractor.dart

class Tractor {
  final String id;
  final String model;
  final String brand;
  final double engineHours;
  final String purchaseDate;
  final String usageIntensity;
  final String ownerId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tractor({
    required this.id,
    required this.model,
    required this.brand,
    required this.engineHours,
    required this.purchaseDate,
    required this.usageIntensity,
    required this.ownerId,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory Tractor.fromJson(Map<String, dynamic> json) {
    return Tractor(
      id: json['id'] ?? json['_id'] ?? '',
      model: json['model'] ?? '',
      brand: json['brand'] ?? '',
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      purchaseDate: json['purchase_date'] ?? '',
      usageIntensity: json['usage_intensity'] ?? 'moderate',
      ownerId: json['owner_id'] ?? '',
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'brand': brand,
      'engine_hours': engineHours,
      'purchase_date': purchaseDate,
      'usage_intensity': usageIntensity,
      'owner_id': ownerId,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Get human-readable usage intensity
  String get displayUsageIntensity {
    switch (usageIntensity.toLowerCase()) {
      case 'light':
        return 'Light Usage';
      case 'moderate':
        return 'Moderate Usage';
      case 'heavy':
        return 'Heavy Usage';
      default:
        return usageIntensity;
    }
  }

  // Get health status based on engine hours
  String get healthStatus {
    if (engineHours < 500) return 'Excellent';
    if (engineHours < 1000) return 'Good';
    if (engineHours < 2000) return 'Fair';
    return 'Needs Attention';
  }

  // Get health color
  String get healthColor {
    if (engineHours < 500) return 'success';
    if (engineHours < 1000) return 'info';
    if (engineHours < 2000) return 'warning';
    return 'error';
  }

  // Calculate days since purchase
  int? get daysSincePurchase {
    try {
      final purchase = DateTime.parse(purchaseDate);
      return DateTime.now().difference(purchase).inDays;
    } catch (e) {
      return null;
    }
  }

  // Copy with method for updates
  Tractor copyWith({
    String? id,
    String? model,
    String? brand,
    double? engineHours,
    String? purchaseDate,
    String? usageIntensity,
    String? ownerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tractor(
      id: id ?? this.id,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      engineHours: engineHours ?? this.engineHours,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      usageIntensity: usageIntensity ?? this.usageIntensity,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
