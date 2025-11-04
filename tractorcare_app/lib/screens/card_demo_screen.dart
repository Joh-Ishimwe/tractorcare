// lib/screens/card_demo_screen.dart

import 'package:flutter/material.dart';
import '../widgets/custom_card.dart';
import '../config/colors.dart';

class CardDemoScreen extends StatelessWidget {
  const CardDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Card Styles'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Card',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Profile Card Example
            ProfileCard(
              name: 'John Farmer',
              email: 'john.farmer@email.com',
              phoneNumber: '+1 (555) 123-4567',
              role: 'Farm Owner',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile card tapped!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Gradient Status Cards',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Good Status Card
            GradientStatusCard(
              tractorModel: 'MF_240',
              tractorId: 'T007',
              hasStatus: true,
              hasBaseline: true,
              gradientColors: AppColors.successGradient,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tractor T007 selected!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Warning Status Card
            GradientStatusCard(
              tractorModel: 'John Deere 5075E',
              tractorId: 'T002',
              hasStatus: true,
              hasBaseline: false,
              gradientColors: AppColors.warningGradient,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tractor T002 needs baseline!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Critical Status Card
            GradientStatusCard(
              tractorModel: 'Case IH Maxxum 145',
              tractorId: 'T005',
              hasStatus: false,
              hasBaseline: true,
              gradientColors: AppColors.errorGradient,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tractor T005 needs attention!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Other Profile Cards',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            // Profile Card with different gradient
            ProfileCard(
              name: 'Sarah Johnson',
              email: 'sarah.j@farmtech.com',
              phoneNumber: '+1 (555) 987-6543',
              role: 'Agricultural Technician',
              gradientColors: [
                AppColors.secondary,
                AppColors.secondaryLight,
              ],
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Technician profile opened!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Profile Card with info gradient
            ProfileCard(
              name: 'Mike Wilson',
              email: 'mike.w@example.com',
              role: 'Equipment Supervisor',
              gradientColors: [
                AppColors.info,
                const Color(0xFF60A5FA),
              ],
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supervisor profile opened!'),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}