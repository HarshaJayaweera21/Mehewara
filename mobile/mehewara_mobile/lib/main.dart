import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Graceful fallback if .env is missing in certain build environments
  }
  final isLoggedIn = await TokenStorage.isLoggedIn();

  runApp(MehewaraMobileApp(
    initialRoute: isLoggedIn ? AppRoutes.crewShell : AppRoutes.initial,
  ));
}

class MehewaraMobileApp extends StatelessWidget {
  final String initialRoute;

  const MehewaraMobileApp({
    super.key,
    this.initialRoute = AppRoutes.initial,
  });

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

class MehewaraApp extends StatelessWidget {
  const MehewaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MehewaraMobileApp(initialRoute: AppRoutes.residentHome);
  }
}
