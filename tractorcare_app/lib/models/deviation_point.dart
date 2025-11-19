// lib/models/deviation_point.dart

class DeviationPoint {
  final DateTime date;
  final double deviation;
  final double? engineHours;
  final String? predictionId;
  final String? baselineStatus;

  DeviationPoint({
    required this.date,
    required this.deviation,
    this.engineHours,
    this.predictionId,
    this.baselineStatus,
  });

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

