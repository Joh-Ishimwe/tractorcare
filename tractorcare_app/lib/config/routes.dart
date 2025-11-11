// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/tractors/tractor_list_screen.dart';
import '../screens/tractors/tractor_detail_screen.dart';
import '../screens/tractors/add_tractor_screen.dart';
import '../screens/audio/recording_screen.dart';
import '../screens/audio/results_screen.dart';
import '../screens/baseline/baseline_setup_screen.dart';
import '../screens/baseline/baseline_collection_screen.dart';
import '../screens/baseline/baseline_status_screen.dart';
import '../screens/maintenance/maintenance_list_screen.dart';
import '../screens/maintenance/maintenance_detail_screen.dart';
import '../screens/maintenance/add_maintenance_screen.dart';
import '../screens/maintenance/maintenance_alerts_screen.dart';
import '../screens/maintenance/calendar_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/home/statistics_screen.dart';
import '../screens/usage/log_usage_screen.dart';
import '../screens/usage/usage_history_screen.dart';
import '../screens/sync/pending_sync_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String tractors = '/tractors';
  static const String tractorDetail = '/tractor-detail';
  static const String addTractor = '/add-tractor';
  static const String recording = '/recording';
  static const String audioResults = '/audio-results';
  static const String baselineSetup = '/baseline-setup';
  static const String baselineCollection = '/baseline-collection';
  static const String baselineStatus = '/baseline-status';
  static const String maintenance = '/maintenance';
  static const String maintenanceDetail = '/maintenance-detail';
  static const String maintenanceAlerts = '/maintenance-alerts';
  static const String addMaintenance = '/add-maintenance';
  static const String calendar = '/calendar';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String statistics = '/statistics';
  static const String logUsage = '/log-usage';
  static const String usageHistory = '/usage-history';
  static const String pendingSync = '/pending-sync';

  static Map<String, WidgetBuilder> get routes => {
        // Remove splash route since we use home: AuthWrapper() instead
        // splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        dashboard: (context) => const DashboardScreen(),
        tractors: (context) => const TractorListScreen(),
        tractorDetail: (context) => const TractorDetailScreen(),
        addTractor: (context) => const AddTractorScreen(),
        recording: (context) => const RecordingScreen(),
        audioResults: (context) => const ResultsScreen(),
        baselineSetup: (context) => const BaselineSetupScreen(),
        baselineCollection: (context) => const BaselineCollectionScreen(),
        baselineStatus: (context) => const BaselineStatusScreen(),
        maintenance: (context) => const MaintenanceListScreen(),
        maintenanceDetail: (context) => const MaintenanceDetailScreen(),
        maintenanceAlerts: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MaintenanceAlertsScreen(tractorId: args['tractor_id']);
        },
        addMaintenance: (context) => const AddMaintenanceScreen(),
        calendar: (context) => const CalendarScreen(),
        profile: (context) => const ProfileScreen(),
        settings: (context) => const SettingsScreen(),
        statistics: (context) => const StatisticsScreen(),
        logUsage: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return LogUsageScreen(
            tractorId: args['tractor_id'],
            currentHours: args['current_hours'],
          );
        },
        usageHistory: (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return UsageHistoryScreen(tractorId: args['tractor_id']);
        },
        pendingSync: (context) => const PendingSyncScreen(),
      };
}