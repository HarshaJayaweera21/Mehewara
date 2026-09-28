import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'features/resident/problems/problem_explorer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Graceful fallback if .env is missing in certain build environments
  }
  runApp(const MehewaraApp());
}

class MehewaraApp extends StatelessWidget {
  const MehewaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mehewara',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: CivicColors.alabaster,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CivicColors.forest,
          primary: CivicColors.forest,
          surface: CivicColors.cardSurface,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const ProblemExplorerScreen(),
    );
  }
}
