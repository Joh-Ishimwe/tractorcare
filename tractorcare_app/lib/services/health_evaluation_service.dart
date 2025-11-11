// lib/services/health_evaluation_service.dart

import '../models/tractor.dart';
import '../models/maintenance.dart';
import '../models/audio_prediction.dart';

class HealthEvaluationService {
  static const int criticalOverdueDays = 30;
  static const int warningOverdueDays = 7;
  static const int criticalSoundThreshold = 80; // Percentage confidence for abnormal sound
  static const int warningSoundThreshold = 60;
  static const int criticalEngineHours = 2000; // High usage threshold
  static const int warningEngineHours = 1500;

  /// Evaluates the overall health status of a tractor based on multiple factors:
  /// - Overdue maintenance tasks
  /// - Recent abnormal sound predictions
  /// - Engine hours and usage intensity
  /// - Baseline completion status
  static TractorStatus evaluateHealthStatus({
    required Tractor tractor,
    List<Maintenance> maintenanceAlerts = const [],
    List<AudioPrediction> recentPredictions = const [],
  }) {
    // Start with unknown status
    TractorStatus currentStatus = TractorStatus.unknown;

    // Factor 1: Check for overdue maintenance (highest priority)
    final maintenanceStatus = _evaluateMaintenanceStatus(maintenanceAlerts);
    if (maintenanceStatus == TractorStatus.critical) {
      return TractorStatus.critical;
    }
    if (maintenanceStatus == TractorStatus.warning) {
      currentStatus = TractorStatus.warning;
    }

    // Factor 2: Check for recent abnormal sound predictions
    final soundStatus = _evaluateSoundStatus(recentPredictions);
    if (soundStatus == TractorStatus.critical) {
      return TractorStatus.critical;
    }
    if (soundStatus == TractorStatus.warning && currentStatus != TractorStatus.warning) {
      currentStatus = TractorStatus.warning;
    }

    // Factor 3: Check engine hours and usage
    final usageStatus = _evaluateUsageStatus(tractor);
    if (usageStatus == TractorStatus.critical) {
      return TractorStatus.critical;
    }
    if (usageStatus == TractorStatus.warning && currentStatus == TractorStatus.unknown) {
      currentStatus = TractorStatus.warning;
    }

    // Factor 4: Check baseline status
    final baselineStatus = _evaluateBaselineStatus(tractor);
    if (baselineStatus == TractorStatus.warning && currentStatus == TractorStatus.unknown) {
      currentStatus = TractorStatus.warning;
    }

    // If no issues found, mark as good
    if (currentStatus == TractorStatus.unknown) {
      return TractorStatus.good;
    }

    return currentStatus;
  }

  /// Evaluates health based on maintenance alerts and overdue tasks
  static TractorStatus _evaluateMaintenanceStatus(List<Maintenance> maintenanceAlerts) {
    if (maintenanceAlerts.isEmpty) {
      return TractorStatus.unknown; // No data to evaluate
    }

    final now = DateTime.now();
    int criticalCount = 0;
    int warningCount = 0;

    for (final alert in maintenanceAlerts) {
      if (alert.status == MaintenanceStatus.completed || 
          alert.status == MaintenanceStatus.cancelled) {
        continue;
      }

      final daysOverdue = now.difference(alert.dueDate).inDays;
      
      // Check if overdue
      if (daysOverdue > criticalOverdueDays) {
        criticalCount++;
      } else if (daysOverdue > warningOverdueDays) {
        warningCount++;
      }
      // Check if due within warning period (upcoming critical)
      else if (daysOverdue >= 0 && alert.status == MaintenanceStatus.due) {
        warningCount++;
      }
    }

    // Determine status based on counts
    if (criticalCount > 0) {
      return TractorStatus.critical;
    }
    if (warningCount > 1) { // Multiple warnings indicate higher risk
      return TractorStatus.critical;
    }
    if (warningCount > 0) {
      return TractorStatus.warning;
    }

    return TractorStatus.unknown; // No maintenance issues
  }

  /// Evaluates health based on recent abnormal sound predictions
  static TractorStatus _evaluateSoundStatus(List<AudioPrediction> recentPredictions) {
    if (recentPredictions.isEmpty) {
      return TractorStatus.unknown;
    }

    // Look at predictions from the last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentAbnormalPredictions = recentPredictions
        .where((p) => 
            p.createdAt.isAfter(sevenDaysAgo) && 
            p.predictionClass == PredictionClass.abnormal)
        .toList();

    if (recentAbnormalPredictions.isEmpty) {
      return TractorStatus.unknown; // No recent abnormal sounds
    }

    // Calculate average confidence of recent abnormal predictions
    final averageConfidence = recentAbnormalPredictions
        .map((p) => p.confidence)
        .reduce((a, b) => a + b) / recentAbnormalPredictions.length;

    // Count of high-confidence abnormal predictions
    final highConfidenceCount = recentAbnormalPredictions
        .where((p) => p.confidence >= criticalSoundThreshold)
        .length;

    // Determine status based on confidence and frequency
    if (averageConfidence >= criticalSoundThreshold || highConfidenceCount >= 3) {
      return TractorStatus.critical;
    }
    if (averageConfidence >= warningSoundThreshold || recentAbnormalPredictions.length >= 2) {
      return TractorStatus.warning;
    }

    return TractorStatus.unknown;
  }

  /// Evaluates health based on engine hours and usage patterns
  static TractorStatus _evaluateUsageStatus(Tractor tractor) {
    final engineHours = tractor.engineHours;
    
    // High usage patterns may indicate increased wear
    if (engineHours >= criticalEngineHours) {
      // Very high hours - requires more attention
      return TractorStatus.warning; // Not critical by itself, but needs monitoring
    }
    
    if (engineHours >= warningEngineHours) {
      // Moderate hours - minor concern
      return TractorStatus.unknown; // Just a note, not a warning yet
    }

    return TractorStatus.unknown;
  }

  /// Evaluates health based on baseline completion status
  static TractorStatus _evaluateBaselineStatus(Tractor tractor) {
    if (!tractor.hasBaseline) {
      // No baseline means we can't properly monitor for abnormalities
      return TractorStatus.warning;
    }

    return TractorStatus.unknown; // Baseline is good
  }

  /// Gets a detailed health report for display purposes
  static Map<String, dynamic> getHealthReport({
    required Tractor tractor,
    List<Maintenance> maintenanceAlerts = const [],
    List<AudioPrediction> recentPredictions = const [],
  }) {
    final status = evaluateHealthStatus(
      tractor: tractor,
      maintenanceAlerts: maintenanceAlerts,
      recentPredictions: recentPredictions,
    );

    final now = DateTime.now();
    final overdueAlerts = maintenanceAlerts
        .where((alert) => 
            alert.status != MaintenanceStatus.completed &&
            alert.status != MaintenanceStatus.cancelled &&
            now.isAfter(alert.dueDate))
        .length;

    final recentAbnormalSounds = recentPredictions
        .where((p) => 
            p.createdAt.isAfter(now.subtract(const Duration(days: 7))) &&
            p.predictionClass == PredictionClass.abnormal)
        .length;

    return {
      'status': status,
      'overdueMaintenanceCount': overdueAlerts,
      'recentAbnormalSounds': recentAbnormalSounds,
      'engineHours': tractor.engineHours,
      'hasBaseline': tractor.hasBaseline,
      'lastCheckDate': tractor.lastCheckDate,
      'recommendations': _getRecommendations(
        status: status,
        overdueCount: overdueAlerts,
        abnormalSoundsCount: recentAbnormalSounds,
        tractor: tractor,
      ),
    };
  }

  /// Gets health recommendations based on current status
  static List<String> _getRecommendations({
    required TractorStatus status,
    required int overdueCount,
    required int abnormalSoundsCount,
    required Tractor tractor,
  }) {
    final recommendations = <String>[];

    if (overdueCount > 0) {
      recommendations.add('Complete $overdueCount overdue maintenance task${overdueCount > 1 ? 's' : ''}');
    }

    if (abnormalSoundsCount > 0) {
      recommendations.add('Investigate recent abnormal sound detections ($abnormalSoundsCount in last 7 days)');
    }

    if (!tractor.hasBaseline) {
      recommendations.add('Complete baseline sound recording for better anomaly detection');
    }

    if (tractor.engineHours >= criticalEngineHours) {
      recommendations.add('High engine hours detected - consider comprehensive inspection');
    }

    if (status == TractorStatus.good && recommendations.isEmpty) {
      recommendations.add('Tractor is in good condition - maintain regular service schedule');
    }

    return recommendations;
  }
}