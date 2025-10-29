// lib/screens/baseline/baseline_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tractor_provider.dart';
import '../../config/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';

class BaselineSetupScreen extends StatefulWidget {
  const BaselineSetupScreen({Key? key}) : super(key: key);

  @override
  State<BaselineSetupScreen> createState() => _BaselineSetupScreenState();
}

class _BaselineSetupScreenState extends State<BaselineSetupScreen> {
  String? _selectedTractorId;

  @override
  void initState() {
    super.initState();
    _loadTractors();
  }

  Future<void> _loadTractors() async {
    final provider = Provider.of<TractorProvider>(context, listen: false);
    await provider.fetchTractors();
  }

  void _startBaselineCollection() {
    if (_selectedTractorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a tractor first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/baseline-collection',
      arguments: _selectedTractorId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baseline Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            CustomCard(
              color: AppColors.info.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'What is a Baseline?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A baseline is a reference recording of your tractor\'s normal engine sound. '
                    'This helps the AI detect when something sounds different or unusual.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Steps
            _buildStepsCard(),

            const SizedBox(height: 24),

            // Select Tractor
            const Text(
              'Select Tractor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Consumer<TractorProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (provider.tractors.isEmpty) {
                  return CustomCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.agriculture_outlined,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Tractors Yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a tractor first to create a baseline',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/add-tractor');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Tractor'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: provider.tractors.map((tractor) {
                    final isSelected = _selectedTractorId == tractor.id;
                    return CustomCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedTractorId = tractor.id;
                        });
                      },
                      child: Row(
                        children: [
                          Radio<String>(
                            value: tractor.id,
                            groupValue: _selectedTractorId,
                            onChanged: (value) {
                              setState(() {
                                _selectedTractorId = value;
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          Text(
                            tractor.statusIcon,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tractor.tractorId,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  tractor.model,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Start Button
            CustomButton(
              text: 'Start Baseline Collection',
              icon: Icons.mic,
              onPressed: _startBaselineCollection,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Collection Steps',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildStep(
            1,
            'Prepare Tractor',
            'Ensure tractor is warmed up and running normally',
            Icons.agriculture,
            AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildStep(
            2,
            'Record Audio',
            'Record 3-5 samples of normal engine sound',
            Icons.mic,
            AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildStep(
            3,
            'AI Analysis',
            'System learns your tractor\'s normal sound pattern',
            Icons.psychology,
            AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    int number,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(icon, color: color, size: 24),
      ],
    );
  }
}