// lib/screens/audio/results_screen.dart

import 'package:flutter/material.dart';
import '../../models/audio_prediction.dart';
import '../../config/colors.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    
    // Handle both old and new argument formats
    AudioPrediction prediction;
    String? tractorId;
    double? engineHours;
    int? recordingDuration;
    
    if (args is Map<String, dynamic>) {
      prediction = args['prediction'] as AudioPrediction;
      tractorId = args['tractor_id'] as String?;
      engineHours = args['engine_hours'] as double?;
      recordingDuration = args['recording_duration'] as int?;
    } else {
      prediction = args as AudioPrediction;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Test Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Header
            _buildStatusHeader(prediction),

            const SizedBox(height: 16),

            // Main Results Card
            _buildMainResultsCard(prediction),

            const SizedBox(height: 16),

            // Detailed Metrics
            _buildDetailedMetrics(prediction),

            const SizedBox(height: 16),

            // Baseline Comparison (if available)
            if (prediction.hasBaseline) _buildBaselineCard(prediction),

            const SizedBox(height: 16),

            // Interpretation
            _buildInterpretationCard(prediction),

            const SizedBox(height: 16),

            // Recommendation
            _buildRecommendationCard(prediction),

            const SizedBox(height: 16),

            // Test Info
            _buildTestInfoCard(prediction),

            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(context, prediction, tractorId, engineHours, recordingDuration),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(AudioPrediction prediction) {
    final color = _getSeverityColor(prediction.severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0), // Reduced from 32 to ~11 (32/3)
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            prediction.statusIcon,
            style: const TextStyle(fontSize: 28), // Reduced from 80 to ~27 (80/3)
          ),
          const SizedBox(height: 6), // Reduced from 16 to ~5 (16/3)
          Text(
            prediction.statusText,
            style: const TextStyle(
              fontSize: 20, // Reduced from 32 to ~11 (32/3), but kept readable at 20
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3), // Reduced from 8 to ~3 (8/3)
          Text(
            prediction.formattedDateTime,
            style: const TextStyle(
              fontSize: 14, // Reduced from 16 to ~14 (16/3 would be too small)
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainResultsCard(AudioPrediction prediction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    'Confidence',
                    prediction.formattedConfidence,
                    Icons.verified,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricBox(
                    'Anomaly Score',
                    prediction.formattedAnomalyScore,
                    Icons.warning_amber,
                    _getSeverityColor(prediction.severity),
                  ),
                ),
              ],
            ),
            if (prediction.anomalyType != AnomalyType.none &&
                prediction.anomalyType != AnomalyType.unknown) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detected Issue',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getAnomalyTypeName(prediction.anomalyType),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics(AudioPrediction prediction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Engine Hours', '${prediction.engineHours} hrs'),
            _buildMetricRow('Prediction Class', prediction.predictionClass.name),
            _buildMetricRow('Severity Level', prediction.severity.toUpperCase()),
            if (prediction.anomalyType != AnomalyType.none)
              _buildMetricRow(
                'Anomaly Type',
                _getAnomalyTypeName(prediction.anomalyType),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaselineCard(AudioPrediction prediction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Baseline Comparison',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Deviation',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Text(
                    prediction.formattedBaselineDeviation,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (prediction.baselineStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                prediction.baselineStatus!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInterpretationCard(AudioPrediction prediction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      color: AppColors.info.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Interpretation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prediction.interpretation,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(AudioPrediction prediction) {
    final color = prediction.isCritical
        ? AppColors.error
        : prediction.isWarning
            ? AppColors.warning
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  prediction.isCritical
                      ? Icons.error
                      : prediction.isWarning
                          ? Icons.warning
                          : Icons.check_circle,
                  color: color,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recommendation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prediction.recommendation,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestInfoCard(AudioPrediction prediction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, 'Date', prediction.formattedDateTime),
            _buildInfoRow(Icons.access_time, 'Time Since Test', prediction.formattedTime),
            _buildInfoRow(Icons.folder, 'Test ID', prediction.id.substring(0, 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AudioPrediction prediction, 
      String? tractorId, double? engineHours, int? recordingDuration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Show recording info if available
          if (recordingDuration != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Text('Recording: ${recordingDuration}s at ${engineHours?.toStringAsFixed(1) ?? 'N/A'}h',
                    style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          
          // Test Again Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                if (tractorId != null && engineHours != null) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/recording',
                    arguments: {
                      'tractor_id': tractorId,
                      'engine_hours': engineHours,
                    },
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.mic),
              label: const Text('RECORD AGAIN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // View Baseline Button (if tractor info available)
          if (tractorId != null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/baseline-status',
                    arguments: {
                      'tractorId': tractorId,
                      'tractorHours': engineHours,
                    },
                  );
                },
                icon: const Icon(Icons.graphic_eq),
                label: const Text('VIEW BASELINE'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.info),
                ),
              ),
            ),
          
          if (tractorId != null) const SizedBox(height: 12),
          
          // Back to Tractor Details
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                if (tractorId != null) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/tractor-detail',
                    (route) => route.settings.name == '/dashboard',
                    arguments: tractorId,
                  );
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.arrow_back),
              label: Text(tractorId != null ? 'BACK TO TRACTOR' : 'BACK TO HOME'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'high':
        return AppColors.audioWarning;
      case 'critical':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getAnomalyTypeName(AnomalyType type) {
    switch (type) {
      case AnomalyType.bearing:
        return 'Bearing Issue';
      case AnomalyType.gearbox:
        return 'Gearbox Issue';
      case AnomalyType.hydraulic:
        return 'Hydraulic Issue';
      case AnomalyType.vibration:
        return 'Excessive Vibration';
      case AnomalyType.none:
        return 'None';
      case AnomalyType.unknown:
        return 'Unknown';
    }
  }
}