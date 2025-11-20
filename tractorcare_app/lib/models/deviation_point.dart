// lib/models/deviation_point.dart


class DeviationPoint {
  final DateTime date;
  final double deviation;
  final double? engineHours;
  final String? predictionId;
  final String? baselineStatus;
  final double? resnetScore;
  final double? combinedScore;
  final String? status;
  final double? deviationPercentage;
  final double? maxDeviation;

  DeviationPoint({
    required this.date,
    required this.deviation,
    this.engineHours,
    this.predictionId,
    this.baselineStatus,
    this.resnetScore,
    this.combinedScore,
    this.status,
    this.deviationPercentage,
    this.maxDeviation,
  });

  factory DeviationPoint.fromJson(Map<String, dynamic> json) {
    return DeviationPoint(
      date: DateTime.parse(json['date']),
      deviation: (json['deviation'] as num).toDouble(),
      engineHours: json['engine_hours'] != null ? (json['engine_hours'] as num).toDouble() : null,
      predictionId: json['prediction_id'],
      baselineStatus: json['baseline_status'],
      resnetScore: json['resnet_score'] != null ? (json['resnet_score'] as num).toDouble() : null,
      combinedScore: json['combined_score'] != null ? (json['combined_score'] as num).toDouble() : null,
      status: json['status'],
      deviationPercentage: json['deviation_percentage'] != null ? (json['deviation_percentage'] as num).toDouble() : null,
      maxDeviation: json['max_deviation'] != null ? (json['max_deviation'] as num).toDouble() : null,
    );
  }

  // Get days since baseline (Day-1 = 0)
  int get daysSinceBaseline {
    // This will be calculated by the provider based on baseline date
    return 0;
  }

  // Get formatted date
  String get formattedDate {
    return '${date.month}/${date.day}/${date.year}';
  }

  // Get formatted deviation
  String get formattedDeviation {
    return deviation.toStringAsFixed(2);
  }
}

