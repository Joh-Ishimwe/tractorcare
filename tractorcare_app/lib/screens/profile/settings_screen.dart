// lib/screens/profile/settings_screen.dart

import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../config/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();

  // Notification Settings
  bool _maintenanceNotifications = true;
  bool _audioTestNotifications = true;
  bool _systemNotifications = true;

  // App Settings
  String _theme = 'system';
  String _language = 'english';
  String _units = 'imperial';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Load settings from storage
    final maintenanceNotif = await _storage.getBool('maintenance_notifications');
    final audioNotif = await _storage.getBool('audio_test_notifications');
    final systemNotif = await _storage.getBool('system_notifications');
    final theme = await _storage.getString('theme');
    final language = await _storage.getString('language');
    final units = await _storage.getString('units');

    setState(() {
      _maintenanceNotifications = maintenanceNotif ?? true;
      _audioTestNotifications = audioNotif ?? true;
      _systemNotifications = systemNotif ?? true;
      _theme = theme ?? 'system';
      _language = language ?? 'english';
      _units = units ?? 'imperial';
    });
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    await _storage.setBool(key, value);
  }

  Future<void> _saveSetting(String key, String value) async {
    await _storage.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifications Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'NOTIFICATIONS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.build,
                        color: AppColors.warning,
                      ),
                    ),
                    title: const Text('Maintenance Reminders'),
                    subtitle: const Text('Get notified when maintenance is due'),
                    value: _maintenanceNotifications,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() => _maintenanceNotifications = value);
                      _saveNotificationSetting('maintenance_notifications', value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: AppColors.info,
                      ),
                    ),
                    title: const Text('Audio Test Results'),
                    subtitle: const Text('Get notified of audio test results'),
                    value: _audioTestNotifications,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() => _audioTestNotifications = value);
                      _saveNotificationSetting('audio_test_notifications', value);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('System Notifications'),
                    subtitle: const Text('App updates and announcements'),
                    value: _systemNotifications,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() => _systemNotifications = value);
                      _saveNotificationSetting('system_notifications', value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Appearance Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'APPEARANCE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.palette,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Theme'),
                    subtitle: Text(_getThemeLabel(_theme)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Preferences Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.language,
                        color: AppColors.info,
                      ),
                    ),
                    title: const Text('Language'),
                    subtitle: Text(_getLanguageLabel(_language)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageDialog(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.straighten,
                        color: AppColors.warning,
                      ),
                    ),
                    title: const Text('Units'),
                    subtitle: Text(_getUnitsLabel(_units)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showUnitsDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'ACCOUNT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: AppColors.error,
                      ),
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text('Permanently delete your account'),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.error,
                    ),
                    onTap: () => _showDeleteAccountDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Legal Section
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'LEGAL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // TODO: Open Terms of Service
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terms of Service coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      // TODO: Open Privacy Policy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy Policy coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('System Default'),
              value: 'system',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                _saveSetting('theme', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'light',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                _saveSetting('theme', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'dark',
              groupValue: _theme,
              onChanged: (value) {
                setState(() => _theme = value!);
                _saveSetting('theme', value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'english',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                _saveSetting('language', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('French'),
              value: 'french',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                _saveSetting('language', value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('French language coming soon'),
                  ),
                );
              },
            ),
            RadioListTile<String>(
              title: const Text('Kinyarwanda'),
              value: 'kinyarwanda',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                _saveSetting('language', value!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kinyarwanda language coming soon'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Units'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Imperial (miles, gallons)'),
              value: 'imperial',
              groupValue: _units,
              onChanged: (value) {
                setState(() => _units = value!);
                _saveSetting('units', value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Metric (km, liters)'),
              value: 'metric',
              groupValue: _units,
              onChanged: (value) {
                setState(() => _units = value!);
                _saveSetting('units', value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delete account feature coming soon'),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(String theme) {
    switch (theme) {
      case 'system':
        return 'System Default';
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  String _getLanguageLabel(String language) {
    switch (language) {
      case 'english':
        return 'English';
      case 'french':
        return 'French';
      case 'kinyarwanda':
        return 'Kinyarwanda';
      default:
        return 'English';
    }
  }

  String _getUnitsLabel(String units) {
    switch (units) {
      case 'imperial':
        return 'Imperial (miles, gallons)';
      case 'metric':
        return 'Metric (km, liters)';
      default:
        return 'Imperial';
    }
  }
}