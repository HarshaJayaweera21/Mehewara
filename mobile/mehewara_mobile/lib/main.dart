import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/resident/problems/problem_explorer_screen.dart';
import 'services/auth/auth_service.dart';
import 'screens/crew_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Graceful fallback if .env is missing in certain build environments
  }
  final isLoggedIn = await TokenStorage.isLoggedIn();
  final role = await TokenStorage.getRole();

  runApp(
    MehewaraMobileApp(
      initialRoute: isLoggedIn
          ? (role?.toUpperCase() == 'RESIDENT' ? AppRoutes.residentHome : AppRoutes.crewShell)
          : AppRoutes.initial,
    ),
  );
}

class MehewaraMobileApp extends StatelessWidget {
  final String initialRoute;

  const MehewaraMobileApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehewara Municipal Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

class CrewApp extends StatelessWidget {
  final CrewSession session;
  const CrewApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mehewara Crew',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f8c)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff3f6fa),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.restoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return session.user == null
            ? CrewLogin(session: session)
            : CrewJobs(key: ValueKey(session.user!['id']), session: session);
      },
    ),
  );
}

class MehewaraApp extends StatelessWidget {
  const MehewaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehewara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ProblemExplorerScreen(),
    );
  }
}
