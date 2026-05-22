import 'package:flutter/material.dart';

import 'screens/application_detail_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/new_application_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';

class MeoMobileApp extends StatelessWidget {
  const MeoMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEO GeoSys Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5C2E),
          primary: const Color(0xFF1A5C2E),
          secondary: const Color(0xFFD4A017),
        ),
        useMaterial3: true,
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/new-application': (_) => const NewApplicationScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/application-detail') {
          final applicationId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => ApplicationDetailScreen(applicationId: applicationId),
          );
        }
        return null;
      },
      home: const LoginScreen(),
    );
  }
}
