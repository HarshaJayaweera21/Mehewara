import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';
import '../../features/crew/crew_shell_screen.dart';
import '../../features/resident/problems/problem_explorer_screen.dart';

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
          builder: (context) => const ProblemExplorerScreen(),
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
