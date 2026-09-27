import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'services/auth/auth_service.dart';
import 'screens/crew_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = CrewSession(ApiClient());
  runApp(CrewApp(session: session));
  session.restore();
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
