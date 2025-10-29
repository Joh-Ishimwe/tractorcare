// lib/config/routes.dart

import 'package:flutter/material.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/tractors/tractor_list_screen.dart';
import '../screens/tractors/tractor_detail_screen.dart';
import '../screens/tractors/add_tractor_screen.dart';
import '../screens/audio/audio_test_screen.dart';
import '../screens/audio/recording_screen.dart';
import '../screens/audio/results_screen.dart';
import '../screens/baseline/baseline_setup_screen.dart';
import '../screens/baseline/baseline_collection_screen.dart';
import '../screens/baseline/baseline_status_screen.dart';
import '../screens/maintenance/maintenance_list_screen.dart';
import '../screens/maintenance/maintenance_detail_screen.dart';
import '../screens/maintenance/add_maintenance_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String tractors = '/tractors';
  static const String tractorDetail = '/tractor-detail';
  static const String addTractor = '/add-tractor';
  static const String audioTest = '/audio-test';
  static const String recording = '/recording';
  static const String audioResults = '/audio-results';
  static const String baselineSetup = '/baseline-setup';
  static const String baselineCollection = '/baseline-collection';
  static const String baselineStatus = '/baseline-status';
  static const String maintenance = '/maintenance';
  static const String maintenanceDetail = '/maintenance-detail';
  static const String addMaintenance = '/add-maintenance';
  static const String profile = '/profile';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        dashboard: (context) => const DashboardScreen(),
        tractors: (context) => const TractorListScreen(),
        tractorDetail: (context) => const TractorDetailScreen(),
        addTractor: (context) => const AddTractorScreen(),
        audioTest: (context) => const AudioTestScreen(),
        recording: (context) => const RecordingScreen(),
        audioResults: (context) => const ResultsScreen(),
        baselineSetup: (context) => const BaselineSetupScreen(),
        baselineCollection: (context) => const BaselineCollectionScreen(),
        baselineStatus: (context) => const BaselineStatusScreen(),
        maintenance: (context) => const MaintenanceListScreen(),
        maintenanceDetail: (context) => const MaintenanceDetailScreen(),
        addMaintenance: (context) => const AddMaintenanceScreen(),
        profile: (context) => const ProfileScreen(),
        settings: (context) => const SettingsScreen(),
      };
}