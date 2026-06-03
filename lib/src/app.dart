import 'package:flutter/material.dart';

import 'screens/application_detail_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/new_application_screen.dart';

class MeoMobileApp extends StatelessWidget {
  const MeoMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEO GeoSys',
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
        '/dashboard': (_) => const DashboardScreen(),
        '/new-application': (_) => const NewApplicationScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/application-detail') {
          final applicationId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) =>
                ApplicationDetailScreen(applicationId: applicationId),
          );
        }
        return null;
      },
      home: const DashboardScreen(),
    );
  }
}
