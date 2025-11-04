// lib/models/tractor.dart

enum TractorStatus {
  good,
  warning,
  critical,
  unknown,
}

class Tractor {
  final String id;
  final String tractorId;
  final String userId;
  final String model;
  final String? make;
  final double engineHours;
  final int? purchaseYear;
  final DateTime? purchaseDate;
  final String? usageIntensity;
  final String? baselineStatus;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final TractorStatus status;
  final DateTime? lastCheckDate;
  final bool hasBaseline;

  Tractor({
    required this.id,
    required this.tractorId,
    required this.userId,
    required this.model,
    this.make,
    required this.engineHours,
    this.purchaseYear,
    this.purchaseDate,
    this.usageIntensity,
    this.baselineStatus,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.status = TractorStatus.unknown,
    this.lastCheckDate,
    this.hasBaseline = false,
  });

  // From JSON
  factory Tractor.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at'];
    final updatedAtStr = json['updated_at'];
    final purchaseDateStr = json['purchase_date'];
    final baselineStatus = json['baseline_status']?.toString().toLowerCase();

    return Tractor(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      userId: json['owner_id'] ?? json['user_id'] ?? '',
      model: json['model'] ?? '',
      make: json['make'],
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      purchaseYear: json['purchase_year'] ?? (purchaseDateStr != null ? DateTime.parse(purchaseDateStr).year : null),
      purchaseDate: purchaseDateStr != null ? DateTime.parse(purchaseDateStr) : null,
      usageIntensity: json['usage_intensity'],
      baselineStatus: json['baseline_status'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now(),
      updatedAt: updatedAtStr != null ? DateTime.parse(updatedAtStr) : null,
      status: _parseHealthStatus(json['health_status'] ?? json['status']),
      lastCheckDate: json['last_check_date'] != null
          ? DateTime.parse(json['last_check_date'])
          : null,
      hasBaseline: baselineStatus == 'completed',
    );
  }

  // Parse status string to enum

  // Map backend health_status to TractorStatus
  static TractorStatus _parseHealthStatus(dynamic statusValue) {
    final s = statusValue?.toString().toLowerCase();
    switch (s) {
      case 'good':
      case 'excellent':
        return TractorStatus.good;
      case 'warning':
      case 'fair':
      case 'moderate':
        return TractorStatus.warning;
      case 'critical':
      case 'poor':
      case 'bad':
        return TractorStatus.critical;
      default:
        return TractorStatus.unknown;
    }
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tractor_id': tractorId,
      'owner_id': userId,
      'model': model,
      'make': make,
      'engine_hours': engineHours,
      'purchase_year': purchaseYear,
      'purchase_date': purchaseDate?.toIso8601String(),
      'usage_intensity': usageIntensity,
      'baseline_status': baselineStatus,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'health_status': status.name,
      'last_check_date': lastCheckDate?.toIso8601String(),
      'has_baseline': hasBaseline,
    };
  }

  // Copy with
  Tractor copyWith({
    String? id,
    String? tractorId,
    String? userId,
    String? model,
    String? make,
    double? engineHours,
    int? purchaseYear,
    DateTime? purchaseDate,
    String? usageIntensity,
    String? baselineStatus,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    TractorStatus? status,
    DateTime? lastCheckDate,
    bool? hasBaseline,
  }) {
    return Tractor(
      id: id ?? this.id,
      tractorId: tractorId ?? this.tractorId,
      userId: userId ?? this.userId,
      model: model ?? this.model,
      make: make ?? this.make,
      engineHours: engineHours ?? this.engineHours,
      purchaseYear: purchaseYear ?? this.purchaseYear,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      usageIntensity: usageIntensity ?? this.usageIntensity,
      baselineStatus: baselineStatus ?? this.baselineStatus,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      lastCheckDate: lastCheckDate ?? this.lastCheckDate,
      hasBaseline: hasBaseline ?? this.hasBaseline,
    );
  }

  // Get status icon
  String get statusIcon {
    switch (status) {
      case TractorStatus.good:
        return '✅';
      case TractorStatus.warning:
        return '⚠️';
      case TractorStatus.critical:
        return '🔴';
      default:
        return '❓';
    }
  }

  // Get status text
  String get statusText {
    switch (status) {
      case TractorStatus.good:
        return 'Good';
      case TractorStatus.warning:
        return 'Warning';
      case TractorStatus.critical:
        return 'Critical';
      default:
        return 'Unknown';
    }
  }

  // Get formatted engine hours
  String get formattedEngineHours {
    return '${engineHours.toStringAsFixed(1)} hrs';
  }

  // Get time since last check
  String get timeSinceLastCheck {
    if (lastCheckDate == null) return 'Never checked';
    
    final difference = DateTime.now().difference(lastCheckDate!);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  // Get tractor age
  String get tractorAge {
    if (purchaseYear == null) return 'Unknown';
    final age = DateTime.now().year - purchaseYear!;
    return age == 0 ? 'New' : '$age years old';
  }

  @override
  String toString() => 'Tractor(id: $tractorId, model: $model)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tractor && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}