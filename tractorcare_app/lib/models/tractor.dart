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
  final double engineHours;
  final int? purchaseYear;
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
    required this.engineHours,
    this.purchaseYear,
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
    return Tractor(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      userId: json['user_id'] ?? '',
      model: json['model'] ?? '',
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      purchaseYear: json['purchase_year'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      status: _parseStatus(json['status']),
      lastCheckDate: json['last_check_date'] != null
          ? DateTime.parse(json['last_check_date'])
          : null,
      hasBaseline: json['has_baseline'] ?? false,
    );
  }

  // Parse status string to enum
  static TractorStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'good':
        return TractorStatus.good;
      case 'warning':
        return TractorStatus.warning;
      case 'critical':
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
      'user_id': userId,
      'model': model,
      'engine_hours': engineHours,
      'purchase_year': purchaseYear,
      'notes': notes,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status.name,
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
    double? engineHours,
    int? purchaseYear,
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
      engineHours: engineHours ?? this.engineHours,
      purchaseYear: purchaseYear ?? this.purchaseYear,
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