// lib/screens/baseline/baseline_status_screen.dart

import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';

class BaselineStatusScreen extends StatelessWidget {
  const BaselineStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baseline Status'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Card
            CustomCard(
              color: AppColors.success.withOpacity(0.1),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Baseline Collection Complete!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your tractor\'s normal sound pattern has been recorded',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.audiotrack,
                    '5',
                    'Samples',
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    Icons.access_time,
                    '45s',
                    'Total Duration',
                    AppColors.info,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    Icons.check_circle,
                    '100%',
                    'Quality',
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    Icons.psychology,
                    'Ready',
                    'AI Status',
                    AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // What's Next
            const Text(
              'What\'s Next?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            CustomCard(
              child: Column(
                children: [
                  _buildNextStep(
                    Icons.mic,
                    'Run Audio Tests',
                    'Compare new recordings against this baseline',
                    AppColors.primary,
                  ),
                  const Divider(height: 24),
                  _buildNextStep(
                    Icons.notifications_active,
                    'Get Alerts',
                    'Receive notifications when anomalies are detected',
                    AppColors.warning,
                  ),
                  const Divider(height: 24),
                  _buildNextStep(
                    Icons.trending_up,
                    'Monitor Trends',
                    'Track engine health over time',
                    AppColors.info,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            CustomButton(
              text: 'Run Audio Test Now',
              icon: Icons.mic,
              onPressed: () {
                Navigator.pushNamed(context, '/audio-test');
              },
              width: double.infinity,
            ),

            const SizedBox(height: 12),

            CustomButton(
              text: 'View Tractor Details',
              icon: Icons.agriculture,
              onPressed: () {
                Navigator.pushNamed(context, '/tractors');
              },
              isOutlined: true,
              width: double.infinity,
            ),

            const SizedBox(height: 12),

            CustomButton(
              text: 'Back to Dashboard',
              icon: Icons.home,
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/dashboard',
                  (route) => false,
                );
              },
              isOutlined: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return CustomCard(
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

  Widget _buildNextStep(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}