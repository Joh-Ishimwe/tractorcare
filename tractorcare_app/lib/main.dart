
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/tractor_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/usage_provider.dart';
import 'providers/maintenance_provider.dart';
import 'providers/deviation_provider.dart';
import 'services/offline_sync_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/dashboard_screen.dart';

void main() {
  // Initialize app with API status logging
  AppConfig.initialize();
  runApp(const TractorCareApp());
}

class TractorCareApp extends StatefulWidget {
  const TractorCareApp({super.key});

  @override
  State<TractorCareApp> createState() => _TractorCareAppState();
}

class _TractorCareAppState extends State<TractorCareApp> {
  late final UsageProvider usageProvider;
  late final MaintenanceProvider maintenanceProvider;
  late final TractorProvider tractorProvider;
  late final AudioProvider audioProvider;
  late final AuthProvider authProvider;
  late final DeviationProvider deviationProvider;

  @override
  void initState() {
    super.initState();
    
    // Initialize providers
    authProvider = AuthProvider();
    usageProvider = UsageProvider();
    maintenanceProvider = MaintenanceProvider();
    tractorProvider = TractorProvider();
    audioProvider = AudioProvider();
    deviationProvider = DeviationProvider();
    
    // Initialize auth provider immediately
    authProvider.init();
    
    // Connect providers after creation
    usageProvider.setMaintenanceProvider(maintenanceProvider);
    audioProvider.setTractorProvider(tractorProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: tractorProvider),
        ChangeNotifierProvider.value(value: audioProvider),
        ChangeNotifierProvider.value(value: usageProvider),
        ChangeNotifierProvider.value(value: maintenanceProvider),
        ChangeNotifierProvider.value(value: deviationProvider),
        ChangeNotifierProvider(
          create: (_) => OfflineSyncService()..initialize(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Show loading screen while auth is initializing
          if (!authProvider.isInitialized) {
            return MaterialApp(
              title: 'TractorCare',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                backgroundColor: Color(0xFF4CAF50),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            );
          }

          return MaterialApp(
            title: 'TractorCare',
            debugShowCheckedModeBanner: false,
            
            // Use AppTheme
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light, 
            
            // Routes
            routes: AppRoutes.routes,
            
            // Determine initial route based on auth status
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

// AuthWrapper widget to handle authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}