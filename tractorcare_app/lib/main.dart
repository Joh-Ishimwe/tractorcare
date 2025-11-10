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
import 'services/offline_sync_service.dart';

void main() {
  // Initialize app with API status logging
  AppConfig.initialize();
  runApp(const TractorCareApp());
}

class TractorCareApp extends StatelessWidget {
  const TractorCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TractorProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
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