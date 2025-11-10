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
import 'services/offline_sync_service.dart';

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

  @override
  void initState() {
    super.initState();
    
    // Initialize providers
    usageProvider = UsageProvider();
    maintenanceProvider = MaintenanceProvider();
    tractorProvider = TractorProvider();
    audioProvider = AudioProvider();
    
    // Connect them after creation
    usageProvider.setMaintenanceProvider(maintenanceProvider);
    audioProvider.setTractorProvider(tractorProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: tractorProvider),
        ChangeNotifierProvider.value(value: audioProvider),
        ChangeNotifierProvider.value(value: usageProvider),
        ChangeNotifierProvider.value(value: maintenanceProvider),
        ChangeNotifierProvider(
          create: (_) => OfflineSyncService()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'TractorCare',
        debugShowCheckedModeBanner: false,
        
        // Use AppTheme
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, 
        
        // Routes
        initialRoute: '/',
        routes: AppRoutes.routes,
        
        // Default route (splash screen)
        // home: const SplashScreen(),
      ),
    );
  }
}