// lib/models/audio_prediction.dart

enum PredictionClass {
  normal,
  abnormal,
  unknown,
}

enum AnomalyType {
  bearing,
  gearbox,
  hydraulic,
  vibration,
  none,
  unknown,
}

class AudioPrediction {
  final String id;
  final String tractorId;
  final String userId;
  final String audioPath;
  final PredictionClass predictionClass;
  final double confidence;
  final double anomalyScore;
  final AnomalyType anomalyType;
  final double? baselineDeviation;
  final int? durationSeconds;
  final String? baselineStatus;
  final double engineHours;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  AudioPrediction({
    required this.id,
    required this.tractorId,
    required this.userId,
    required this.audioPath,
    required this.predictionClass,
    required this.confidence,
    required this.anomalyScore,
    required this.anomalyType,
    this.baselineDeviation,
    this.durationSeconds,
    this.baselineStatus,
    required this.engineHours,
    this.metadata,
    required this.createdAt,
  });

  // From JSON
  factory AudioPrediction.fromJson(Map<String, dynamic> json) {
    return AudioPrediction(
      id: json['id'] ?? json['_id'] ?? '',
      tractorId: json['tractor_id'] ?? '',
      userId: json['user_id'] ?? '',
      audioPath: json['audio_path'] ?? '',
      predictionClass: _parsePredictionClass(json['prediction_class']),
      confidence: (json['confidence'] ?? 0).toDouble(),
      anomalyScore: (json['anomaly_score'] ?? 0).toDouble(),
      anomalyType: _parseAnomalyType(json['anomaly_type']),
    baselineDeviation: json['baseline_deviation'] != null
      ? (json['baseline_deviation'] as num).toDouble()
      : // Try nested baseline_comparison.deviation_score
      (json['baseline_comparison'] != null && json['baseline_comparison']['deviation_score'] != null)
        ? (json['baseline_comparison']['deviation_score'] as num).toDouble()
        : null,
    baselineStatus: json['baseline_status'] ?? (json['baseline_comparison'] != null ? json['baseline_comparison']['combined_status'] : null),
    durationSeconds: json['duration_seconds'] != null ? (json['duration_seconds'] as num).toInt() : null,
      engineHours: (json['engine_hours'] ?? 0).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    // Accept both 'created_at' and 'recorded_at' keys used by the backend
    createdAt: (json['created_at'] ?? json['recorded_at']) != null
      ? DateTime.parse((json['created_at'] ?? json['recorded_at']).toString())
      : DateTime.now(),
    );
  }

  // Parse prediction class
  static PredictionClass _parsePredictionClass(String? value) {
    switch (value?.toLowerCase()) {
      case 'normal':
        return PredictionClass.normal;
      case 'abnormal':
        return PredictionClass.abnormal;
      default:
        return PredictionClass.unknown;
    }
  }

  // Parse anomaly type
  static AnomalyType _parseAnomalyType(String? value) {
    switch (value?.toLowerCase()) {
      case 'bearing':
        return AnomalyType.bearing;
      case 'gearbox':
        return AnomalyType.gearbox;
      case 'hydraulic':
        return AnomalyType.hydraulic;
      case 'vibration':
        return AnomalyType.vibration;
      case 'none':
        return AnomalyType.none;
      default:
        return AnomalyType.unknown;
    }
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tractor_id': tractorId,
      'user_id': userId,
      'audio_path': audioPath,
      'prediction_class': predictionClass.name,
      'confidence': confidence,
      'anomaly_score': anomalyScore,
      'anomaly_type': anomalyType.name,
      'baseline_deviation': baselineDeviation,
      'baseline_status': baselineStatus,
      'engine_hours': engineHours,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Get status icon
  String get statusIcon {
    if (predictionClass == PredictionClass.unknown) return '❓';
    if (predictionClass == PredictionClass.normal) return '✅';
    if (anomalyScore < 0.6) return '⚠️';
    return '🔴';
  }

  // Get status text
  String get statusText {
    if (predictionClass == PredictionClass.unknown) return 'Unknown Sound';
    if (predictionClass == PredictionClass.normal) return 'Normal';
    if (anomalyScore < 0.6) return 'Minor Issue';
    if (anomalyScore < 0.75) return 'Warning';
    return 'Critical';
  }

  // Get status color (for UI)
  String get statusColorHex {
    if (predictionClass == PredictionClass.normal) return '#10b981'; // Green
    if (anomalyScore < 0.6) return '#f59e0b'; // Orange
    if (anomalyScore < 0.75) return '#f59e0b'; // Orange
    return '#ef4444'; // Red
  }

  // Get interpretation message
  String get interpretation {
    if (predictionClass == PredictionClass.unknown) {
      return 'Audio does not appear to be from a tractor. Please record the tractor engine sound directly.';
    } else if (predictionClass == PredictionClass.normal) {
      return 'Sound appears normal';
    } else if (anomalyScore < 0.6) {
      return 'Minor irregularity detected';
    } else if (anomalyScore < 0.75) {
      return 'Unusual sound pattern detected';
    } else if (anomalyScore < 0.9) {
      return 'High vibration or unusual noise detected';
    } else {
      return 'Critical anomaly detected';
    }
  }

  // Get recommendation
  String get recommendation {
    if (predictionClass == PredictionClass.unknown) {
      return 'Please record the tractor engine sound directly in a quiet environment. Ensure the microphone is close to the engine and avoid background noise, speech, or music.';
    } else if (predictionClass == PredictionClass.normal) {
      return 'No immediate concerns detected';
    } else if (anomalyScore < 0.6) {
      return 'Monitor the equipment, but no urgent action needed';
    } else if (anomalyScore < 0.75) {
      return 'Consider scheduling an inspection';
    } else if (anomalyScore < 0.9) {
      return 'Schedule maintenance soon';
    } else {
      return 'Immediate inspection recommended';
    }
  }

  // Get severity level
  String get severity {
    if (predictionClass == PredictionClass.unknown) return 'unknown';
    if (predictionClass == PredictionClass.normal) return 'low';
    if (anomalyScore < 0.6) return 'low';
    if (anomalyScore < 0.75) return 'medium';
    if (anomalyScore < 0.9) return 'high';
    return 'critical';
  }

  // Get formatted confidence
  String get formattedConfidence {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  // Get formatted anomaly score
  String get formattedAnomalyScore {
    return anomalyScore.toStringAsFixed(2);
  }

  // Get formatted baseline deviation
  String get formattedBaselineDeviation {
    if (baselineDeviation == null) return 'N/A';
    return '${baselineDeviation!.toStringAsFixed(1)}σ';
  }

  // Get formatted time
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as date
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }

  // Get formatted date time
  String get formattedDateTime {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final month = months[createdAt.month - 1];
    final day = createdAt.day;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final hour12 = createdAt.hour > 12 ? createdAt.hour - 12 : createdAt.hour;
    
    return '$month $day, $hour12:$minute $period';
  }

  // Has baseline comparison
  bool get hasBaseline {
    return baselineDeviation != null;
  }

  // Is critical
  bool get isCritical {
    return severity == 'critical';
  }

  // Is warning
  bool get isWarning {
    return severity == 'high' || severity == 'medium';
  }

  // Is normal
  bool get isNormal {
    return severity == 'low' && predictionClass == PredictionClass.normal;
  }

  @override
  String toString() =>
      'AudioPrediction(id: $id, class: $predictionClass, confidence: $confidence)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioPrediction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}