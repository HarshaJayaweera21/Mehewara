import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isLoggedIn = await TokenStorage.isLoggedIn();

  runApp(MehewaraMobileApp(
    initialRoute: isLoggedIn ? AppRoutes.crewShell : AppRoutes.initial,
  ));
}

class MehewaraMobileApp extends StatelessWidget {
  final String initialRoute;

  const MehewaraMobileApp({
    super.key,
    required this.initialRoute,
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
