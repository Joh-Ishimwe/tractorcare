// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tractor_provider.dart';
import '../../config/colors.dart';
import '../../widgets/custom_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tractorProvider = Provider.of<TractorProvider>(context, listen: false);
    await tractorProvider.fetchTractors();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ProfileCard(
                name: user?.fullName ?? 'User',
                email: user?.email ?? '',
                phoneNumber: user?.phoneNumber,
                role: 'Farmer', // You can add role to user model or make it dynamic
                onTap: () {
                  // Navigate to edit profile or show profile details
                },
              ),
            ),

            const SizedBox(height: 16),

            // Menu Items
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildMenuItem(
                    Icons.person,
                    'Edit Profile',
                    'Update your personal information',
                    () {
                      // TODO: Navigate to edit profile
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit profile feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    Icons.lock,
                    'Change Password',
                    'Update your password',
                    () {
                      // TODO: Navigate to change password
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Change password feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    Icons.notifications,
                    'Notifications',
                    'Manage notification preferences',
                    () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    Icons.help,
                    'Help & Support',
                    'Get help and support',
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Help & support feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    Icons.info,
                    'About',
                    'App version and information',
                    () {
                      _showAboutDialog();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('LOGOUT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'TractorCare',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '🚜',
            style: TextStyle(fontSize: 30),
          ),
        ),
      ),
      children: [
        const Text(
          'Smart Maintenance for Smart Farming',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'TractorCare helps farmers monitor and maintain their tractors using AI-powered audio analysis.',
        ),
        const SizedBox(height: 16),
        const Text(
          '© 2025 TractorCare. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}