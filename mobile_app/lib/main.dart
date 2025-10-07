import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const TractorCareApp());
}

class TractorCareApp extends StatelessWidget {
  const TractorCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TractorCare',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(), // Start with login
      debugShowCheckedModeBanner: false,
    );
  }
}