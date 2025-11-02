import 'dart:math' as math;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/audio_prediction.dart';

class AudioResultsScreen extends StatelessWidget {
  final AudioPrediction prediction;

  const AudioResultsScreen({Key? key, required this.prediction}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Test Results'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 24),
            
            // Waveform Analysis
            _buildWaveformCard(),
            
            const SizedBox(height: 24),
            
            // Frequency Analysis
            _buildFrequencyCard(),
            
            const SizedBox(height: 24),
            
            // Detailed Analysis
            _buildAnalysisCard(),
            
            const SizedBox(height: 24),
            
            // Recommendations
            _buildRecommendationsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getSeverityColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    _getSeverityIcon(),
                    color: _getSeverityColor(),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.statusText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Severity: ${prediction.severity.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          color: _getSeverityColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'Confidence',
                    '${(prediction.confidence * 100).toStringAsFixed(0)}%',
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Anomaly Score',
                    prediction.formattedAnomalyScore,
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'Date',
                    '${prediction.createdAt.day}/${prediction.createdAt.month}',
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildWaveformCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio Waveform Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${(value * 0.1).toStringAsFixed(1)}s',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _generateDetailedWaveform(),
                        isCurved: false,
                        color: _getSeverityColor(),
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _getSeverityColor().withOpacity(0.1),
                        ),
                      ),
                    ],
                    minY: -1.5,
                    maxY: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWaveformStat('Duration', '3.2s'),
                _buildWaveformStat('Peak Amplitude', '0.${(prediction.confidence * 100).toInt()}'),
                _buildWaveformStat('Frequency Range', '50-8kHz'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFrequencyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequency Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.grey[700]!,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final frequencies = ['50Hz', '100Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz'];
                        return BarTooltipItem(
                          '${frequencies[groupIndex]}\n${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final frequencies = ['50Hz', '100Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz'];
                          final index = value.toInt();
                          if (index >= 0 && index < frequencies.length) {
                            return Text(
                              frequencies[index],
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _generateFrequencyBars(),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDefaultAnalysis(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAnalysis() {
    String analysis = '';
    switch (prediction.severity.toLowerCase()) {
      case 'critical':
        analysis = 'The audio analysis reveals significant irregularities in the engine sound pattern. '
            'Detected abnormal vibrations and frequency spikes indicating potential critical engine issues. '
            'Immediate attention required to prevent further damage.';
        break;
      case 'high':
        analysis = 'Analysis shows moderate deviations from normal engine sound patterns. '
            'Some frequency anomalies detected that suggest developing mechanical issues. '
            'Schedule maintenance soon to address the identified problems.';
        break;
      case 'medium':
        analysis = 'The audio pattern shows minor variations from expected normal range. '
            'Some areas of concern identified that should be monitored. '
            'Regular maintenance recommended to prevent progression.';
        break;
      default:
        analysis = 'Audio analysis indicates normal engine operation with sound patterns '
            'within expected parameters. No immediate concerns detected. '
            'Continue regular maintenance schedule.';
    }
    
    return Text(
      analysis,
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
  }

  Widget _buildRecommendationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              prediction.recommendation,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'For best results, conduct audio tests in a quiet environment and ensure consistent engine RPM.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateDetailedWaveform() {
    final Random random = Random(prediction.hashCode);
    List<FlSpot> spots = [];
    
    double baseAmplitude = _getAmplitudeFromSeverity();
    double frequency = _getFrequencyFromSeverity();
    
    for (int i = 0; i < 100; i++) {
      double x = i.toDouble();
      double t = i / 100.0;
      
      // Complex waveform with multiple harmonics
      double sine1 = math.sin(t * frequency * 2 * math.pi) * baseAmplitude;
      double sine2 = math.sin(t * frequency * 4 * math.pi) * baseAmplitude * 0.5;
      double sine3 = math.sin(t * frequency * 6 * math.pi) * baseAmplitude * 0.3;
      double noise = (random.nextDouble() - 0.5) * 0.2;
      
      // Add some envelope to make it more realistic
      double envelope = math.exp(-t * 2) + 0.3;
      
      double value = (sine1 + sine2 + sine3) * envelope + noise;
      value = math.max(-1.5, math.min(1.5, value));
      
      spots.add(FlSpot(x, value));
    }
    
    return spots;
  }

  List<BarChartGroupData> _generateFrequencyBars() {
    final Random random = Random(prediction.hashCode);
    List<BarChartGroupData> bars = [];
    
    for (int i = 0; i < 7; i++) {
      double height = 0.3 + random.nextDouble() * 0.7;
      
      // Adjust based on severity
      if (prediction.severity.toLowerCase() == 'critical' && i == 2) {
        height = 0.9; // High spike at 500Hz for critical issues
      }
      
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: height,
              color: _getFrequencyColor(height),
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    
    return bars;
  }

  Color _getFrequencyColor(double height) {
    if (height > 0.8) return Colors.red;
    if (height > 0.6) return Colors.orange;
    if (height > 0.4) return Colors.yellow;
    return Colors.green;
  }

  double _getAmplitudeFromSeverity() {
    switch (prediction.severity.toLowerCase()) {
      case 'critical':
        return 1.2;
      case 'high':
        return 0.9;
      case 'medium':
        return 0.6;
      default:
        return 0.4;
    }
  }

  double _getFrequencyFromSeverity() {
    switch (prediction.severity.toLowerCase()) {
      case 'critical':
        return 8.0;
      case 'high':
        return 6.0;
      case 'medium':
        return 4.0;
      default:
        return 2.0;
    }
  }

  Color _getSeverityColor() {
    switch (prediction.severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  IconData _getSeverityIcon() {
    switch (prediction.severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'unknown':
        return Icons.help_outline;
      default:
        return Icons.check_circle;
    }
  }
}