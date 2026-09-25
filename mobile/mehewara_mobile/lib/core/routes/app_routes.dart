import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';
import '../../features/crew/crew_shell_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String login = '/login';
  static const String crewShell = '/crew';
  static const String residentHome = '/resident';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );

      case crewShell:
        return MaterialPageRoute(
          builder: (context) => CrewShellScreen(
            onLogout: () {
              Navigator.of(context).pushNamedAndRemoveUntil(login, (route) => false);
            },
          ),
          settings: settings,
        );

      case residentHome:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Resident Portal')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.maps_home_work_outlined, size: 54, color: Color(0xFF123C32)),
                    const SizedBox(height: 16),
                    const Text(
                      'Resident Issue Reporting Portal',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This module is owned by Member 1 (Report & Intake Management). You can switch to Crew Leader Mode to inspect Member 3 screens.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed(login),
                      child: const Text('Switch to Crew Leader Mode'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
