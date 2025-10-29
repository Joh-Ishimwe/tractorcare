// lib/models/maintenance.dart

enum MaintenanceType {
  oilChange,
  filterReplacement,
  inspection,
  repair,
  service,
  other,
}

enum MaintenanceStatus {
  upcoming,
  due,
  overdue,
  completed,
  cancelled,
}

class Maintenance {
  final String id;
  final String tractorId;
  final String userId;
  final MaintenanceType type;
  final String? customType; // For "other" type
  final DateTime dueDate;
  final double? dueAtHours;
  final double? estimatedCost;
  final String? notes;
  final MaintenanceStatus status;
  final DateTime? completedAt;
  final double? actualCost;
  final String? completedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Maintenance({
    required this.id,
    required this.tractorId,
    required this.userId,
    required this.type,
    this.customType,
    required this.dueDate,
    this.dueAtHours,
    this.estimatedCost,
    this.notes,
    this.status = MaintenanceStatus.upcoming,
    this.completedAt,
    this.actualCost,
    this.completedBy,
    required this.createdAt,
    this.updatedAt,
  });

  // From JSON
  factory Maintenance.fromJson(Map<String, dynamic> json) {
    return Maintenance(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      userId: json['user_id'] ?? '',
      type: _parseMaintenanceType(json['type']),
      customType: json['custom_type'],
      dueDate: DateTime.parse(json['due_date']),
      dueAtHours: json['due_at_hours'] != null
          ? (json['due_at_hours'] as num).toDouble()
          : null,
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      notes: json['notes'],
      status: _parseStatus(json['status']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      actualCost: json['actual_cost'] != null
          ? (json['actual_cost'] as num).toDouble()
          : null,
      completedBy: json['completed_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // Parse maintenance type
  static MaintenanceType _parseMaintenanceType(String? value) {
    switch (value?.toLowerCase().replaceAll(' ', '_')) {
      case 'oil_change':
        return MaintenanceType.oilChange;
      case 'filter_replacement':
        return MaintenanceType.filterReplacement;
      case 'inspection':
        return MaintenanceType.inspection;
      case 'repair':
        return MaintenanceType.repair;
      case 'service':
        return MaintenanceType.service;
      default:
        return MaintenanceType.other;
    }
  }

  // Parse status
  static MaintenanceStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'upcoming':
        return MaintenanceStatus.upcoming;
      case 'due':
        return MaintenanceStatus.due;
      case 'overdue':
        return MaintenanceStatus.overdue;
      case 'completed':
        return MaintenanceStatus.completed;
      case 'cancelled':
        return MaintenanceStatus.cancelled;
      default:
        return MaintenanceStatus.upcoming;
    }
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tractor_id': tractorId,
      'user_id': userId,
      'type': typeString,
      'custom_type': customType,
      'due_date': dueDate.toIso8601String(),
      'due_at_hours': dueAtHours,
      'estimated_cost': estimatedCost,
      'notes': notes,
      'status': status.name,
      'completed_at': completedAt?.toIso8601String(),
      'actual_cost': actualCost,
      'completed_by': completedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Copy with
  Maintenance copyWith({
    String? id,
    String? tractorId,
    String? userId,
    MaintenanceType? type,
    String? customType,
    DateTime? dueDate,
    double? dueAtHours,
    double? estimatedCost,
    String? notes,
    MaintenanceStatus? status,
    DateTime? completedAt,
    double? actualCost,
    String? completedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Maintenance(
      id: id ?? this.id,
      tractorId: tractorId ?? this.tractorId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      customType: customType ?? this.customType,
      dueDate: dueDate ?? this.dueDate,
      dueAtHours: dueAtHours ?? this.dueAtHours,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      actualCost: actualCost ?? this.actualCost,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get type string
  String get typeString {
    switch (type) {
      case MaintenanceType.oilChange:
        return 'Oil Change';
      case MaintenanceType.filterReplacement:
        return 'Filter Replacement';
      case MaintenanceType.inspection:
        return 'Inspection';
      case MaintenanceType.repair:
        return 'Repair';
      case MaintenanceType.service:
        return 'Service';
      case MaintenanceType.other:
        return customType ?? 'Other';
    }
  }

  // Get type for API
  String get typeForApi {
    switch (type) {
      case MaintenanceType.oilChange:
        return 'oil_change';
      case MaintenanceType.filterReplacement:
        return 'filter_replacement';
      case MaintenanceType.inspection:
        return 'inspection';
      case MaintenanceType.repair:
        return 'repair';
      case MaintenanceType.service:
        return 'service';
      case MaintenanceType.other:
        return 'other';
    }
  }

  // Get status icon
  String get statusIcon {
    switch (status) {
      case MaintenanceStatus.upcoming:
        return '🟡';
      case MaintenanceStatus.due:
        return '🟠';
      case MaintenanceStatus.overdue:
        return '🔴';
      case MaintenanceStatus.completed:
        return '✅';
      case MaintenanceStatus.cancelled:
        return '❌';
    }
  }

  // Get status text
  String get statusText {
    switch (status) {
      case MaintenanceStatus.upcoming:
        return 'Upcoming';
      case MaintenanceStatus.due:
        return 'Due';
      case MaintenanceStatus.overdue:
        return 'Overdue';
      case MaintenanceStatus.completed:
        return 'Completed';
      case MaintenanceStatus.cancelled:
        return 'Cancelled';
    }
  }

  // Get type icon
  String get typeIcon {
    switch (type) {
      case MaintenanceType.oilChange:
        return '🛢️';
      case MaintenanceType.filterReplacement:
        return '🔧';
      case MaintenanceType.inspection:
        return '🔍';
      case MaintenanceType.repair:
        return '🔨';
      case MaintenanceType.service:
        return '⚙️';
      case MaintenanceType.other:
        return '📝';
    }
  }

  // Get formatted due date
  String get formattedDueDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dueDate.month - 1]} ${dueDate.day}, ${dueDate.year}';
  }

  // Get days until due
  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  // Get time until due (human readable)
  String get timeUntilDue {
    final days = daysUntilDue;
    
    if (days < 0) {
      return '${-days} days overdue';
    } else if (days == 0) {
      return 'Due today';
    } else if (days == 1) {
      return 'Due tomorrow';
    } else if (days < 7) {
      return 'Due in $days days';
    } else if (days < 30) {
      final weeks = (days / 7).floor();
      return 'Due in $weeks ${weeks == 1 ? 'week' : 'weeks'}';
    } else {
      final months = (days / 30).floor();
      return 'Due in $months ${months == 1 ? 'month' : 'months'}';
    }
  }

  // Get hours remaining (if dueAtHours is set)
  double? hoursRemaining(double currentHours) {
    if (dueAtHours == null) return null;
    return dueAtHours! - currentHours;
  }

  // Get formatted hours remaining
  String formattedHoursRemaining(double currentHours) {
    final remaining = hoursRemaining(currentHours);
    if (remaining == null) return 'N/A';
    
    if (remaining < 0) {
      return '${(-remaining).toStringAsFixed(1)} hrs overdue';
    } else {
      return 'In ${remaining.toStringAsFixed(1)} hrs';
    }
  }

  // Get formatted cost
  String get formattedEstimatedCost {
    if (estimatedCost == null) return 'N/A';
    return '\$${estimatedCost!.toStringAsFixed(2)}';
  }

  String get formattedActualCost {
    if (actualCost == null) return 'N/A';
    return '\$${actualCost!.toStringAsFixed(2)}';
  }

  // Is completed
  bool get isCompleted {
    return status == MaintenanceStatus.completed;
  }

  // Is overdue
  bool get isOverdue {
    return status == MaintenanceStatus.overdue || daysUntilDue < 0;
  }

  // Is due soon (within 7 days)
  bool get isDueSoon {
    return daysUntilDue >= 0 && daysUntilDue <= 7;
  }

  @override
  String toString() =>
      'Maintenance(id: $id, type: $typeString, status: $statusText)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Maintenance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}