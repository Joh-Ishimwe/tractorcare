// lib/models/baseline.dart

enum BaselineStatus {
  inProgress,
  active,
  inactive,
  expired,
}

class BaselineSample {
  final String id;
  final String audioPath;
  final double engineHours;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  BaselineSample({
    required this.id,
    required this.audioPath,
    required this.engineHours,
    required this.timestamp,
    this.metadata,
  });

  factory BaselineSample.fromJson(Map<String, dynamic> json) {
    return BaselineSample(
      id: json['id'] ?? '',
      audioPath: json['audio_path'] ?? '',
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audio_path': audioPath,
      'engine_hours': engineHours,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}

class Baseline {
  final String id;
  final String tractorId;
  final String userId;
  final BaselineStatus status;
  final double engineHoursAtCreation;
  final String? loadCondition;
  final int samplesCollected;
  final int totalSamplesRequired;
  final double? confidence;
  final List<BaselineSample> samples;
  final DateTime createdAt;
  final DateTime? finalizedAt;
  final DateTime? updatedAt;

  Baseline({
    required this.id,
    required this.tractorId,
    required this.userId,
    required this.status,
    required this.engineHoursAtCreation,
    this.loadCondition,
    required this.samplesCollected,
    this.totalSamplesRequired = 5,
    this.confidence,
    this.samples = const [],
    required this.createdAt,
    this.finalizedAt,
    this.updatedAt,
  });

  // From JSON
  factory Baseline.fromJson(Map<String, dynamic> json) {
    return Baseline(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      userId: json['user_id'] ?? '',
      status: _parseStatus(json['status']),
      engineHoursAtCreation: (json['engine_hours_at_creation'] ?? 0).toDouble(),
      loadCondition: json['load_condition'],
      samplesCollected: json['samples_collected'] ?? 0,
      totalSamplesRequired: json['total_samples_required'] ?? 5,
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : null,
      samples: json['samples'] != null
          ? (json['samples'] as List)
              .map((s) => BaselineSample.fromJson(s))
              .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      finalizedAt: json['finalized_at'] != null
          ? DateTime.parse(json['finalized_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  // Parse status
  static BaselineStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'in_progress':
        return BaselineStatus.inProgress;
      case 'active':
        return BaselineStatus.active;
      case 'inactive':
        return BaselineStatus.inactive;
      case 'expired':
        return BaselineStatus.expired;
      default:
        return BaselineStatus.inProgress;
    }
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tractor_id': tractorId,
      'user_id': userId,
      'status': statusString,
      'engine_hours_at_creation': engineHoursAtCreation,
      'load_condition': loadCondition,
      'samples_collected': samplesCollected,
      'total_samples_required': totalSamplesRequired,
      'confidence': confidence,
      'samples': samples.map((s) => s.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'finalized_at': finalizedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Copy with
  Baseline copyWith({
    String? id,
    String? tractorId,
    String? userId,
    BaselineStatus? status,
    double? engineHoursAtCreation,
    String? loadCondition,
    int? samplesCollected,
    int? totalSamplesRequired,
    double? confidence,
    List<BaselineSample>? samples,
    DateTime? createdAt,
    DateTime? finalizedAt,
    DateTime? updatedAt,
  }) {
    return Baseline(
      id: id ?? this.id,
      tractorId: tractorId ?? this.tractorId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      engineHoursAtCreation: engineHoursAtCreation ?? this.engineHoursAtCreation,
      loadCondition: loadCondition ?? this.loadCondition,
      samplesCollected: samplesCollected ?? this.samplesCollected,
      totalSamplesRequired: totalSamplesRequired ?? this.totalSamplesRequired,
      confidence: confidence ?? this.confidence,
      samples: samples ?? this.samples,
      createdAt: createdAt ?? this.createdAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get status string
  String get statusString {
    switch (status) {
      case BaselineStatus.inProgress:
        return 'in_progress';
      case BaselineStatus.active:
        return 'active';
      case BaselineStatus.inactive:
        return 'inactive';
      case BaselineStatus.expired:
        return 'expired';
    }
  }

  // Get status text
  String get statusText {
    switch (status) {
      case BaselineStatus.inProgress:
        return 'In Progress';
      case BaselineStatus.active:
        return 'Active';
      case BaselineStatus.inactive:
        return 'Inactive';
      case BaselineStatus.expired:
        return 'Expired';
    }
  }

  // Get status icon
  String get statusIcon {
    switch (status) {
      case BaselineStatus.inProgress:
        return '🔄';
      case BaselineStatus.active:
        return '✅';
      case BaselineStatus.inactive:
        return '⏸️';
      case BaselineStatus.expired:
        return '⚠️';
    }
  }

  // Get progress percentage
  double get progressPercentage {
    return (samplesCollected / totalSamplesRequired) * 100;
  }

  // Get formatted progress
  String get formattedProgress {
    return '$samplesCollected/$totalSamplesRequired';
  }

  // Get formatted confidence
  String get formattedConfidence {
    if (confidence == null) return 'N/A';
    return '${(confidence! * 100).toStringAsFixed(0)}%';
  }

  // Get formatted created date
  String get formattedCreatedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  // Get formatted engine hours
  String get formattedEngineHours {
    return '${engineHoursAtCreation.toStringAsFixed(1)} hrs';
  }

  // Is complete
  bool get isComplete {
    return samplesCollected >= totalSamplesRequired;
  }

  // Is active
  bool get isActive {
    return status == BaselineStatus.active;
  }

  // Is in progress
  bool get isInProgress {
    return status == BaselineStatus.inProgress;
  }

  // Can add sample
  bool get canAddSample {
    return status == BaselineStatus.inProgress && !isComplete;
  }

  // Samples remaining
  int get samplesRemaining {
    return totalSamplesRequired - samplesCollected;
  }

  // Get next sample number
  int get nextSampleNumber {
    return samplesCollected + 1;
  }

  // Get load condition display
  String get loadConditionDisplay {
    return loadCondition ?? 'Normal';
  }

  @override
  String toString() =>
      'Baseline(id: $id, status: $statusText, progress: $formattedProgress)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Baseline && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}