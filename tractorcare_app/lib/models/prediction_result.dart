// lib/models/prediction_result.dart

class PredictionResult {
  final String predictedIssue;
  final String severity;
  final double confidence;
  final String recommendation;
  final double estimatedCost;
  final String? audioAnalysis;
  final Map<String, dynamic>? mlPrediction;
  final Map<String, dynamic>? ruleBasedPrediction;
  final DateTime timestamp;

  PredictionResult({
    required this.predictedIssue,
    required this.severity,
    required this.confidence,
    required this.recommendation,
    required this.estimatedCost,
    this.audioAnalysis,
    this.mlPrediction,
    this.ruleBasedPrediction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      predictedIssue: json['predicted_issue'] ?? json['issue'] ?? 'Unknown',
      severity: json['severity'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      recommendation: json['recommendation'] ?? '',
      estimatedCost: (json['estimated_cost'] ?? 0).toDouble(),
      audioAnalysis: json['audio_analysis'],
      mlPrediction: json['ml_prediction'],
      ruleBasedPrediction: json['rule_based_prediction'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predicted_issue': predictedIssue,
      'severity': severity,
      'confidence': confidence,
      'recommendation': recommendation,
      'estimated_cost': estimatedCost,
      if (audioAnalysis != null) 'audio_analysis': audioAnalysis,
      if (mlPrediction != null) 'ml_prediction': mlPrediction,
      if (ruleBasedPrediction != null) 'rule_based_prediction': ruleBasedPrediction,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Get severity display name
  String get displaySeverity {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      case 'normal':
        return 'Normal';
      default:
        return severity;
    }
  }

  // Get severity color
  String get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'error';
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      case 'low':
      case 'normal':
        return 'success';
      default:
        return 'info';
    }
  }

  // Get confidence percentage
  String get confidencePercentage {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  // Get formatted cost
  String get formattedCost {
    return '${estimatedCost.toStringAsFixed(0)} RWF';
  }

  // Check if prediction is reliable (confidence > 70%)
  bool get isReliable {
    return confidence >= 0.7;
  }

  // Get confidence level text
  String get confidenceLevel {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.7) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  // Get issue summary
  String get summary {
    return '$predictedIssue (${displaySeverity})';
  }
}
