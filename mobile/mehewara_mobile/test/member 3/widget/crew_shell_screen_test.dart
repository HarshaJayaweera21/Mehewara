import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/features/crew/crew_shell_screen.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') return true;
        if (methodCall.method == 'checkPermission') return 3;
        return null;
      },
    );
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'email': 'sunil.perera@colombo.gov.lk'});
    SharedPreferences.setMockInitialValues({});
  });

  group('CrewShellScreen Widget Tests (Member 3)', () {
    testWidgets('renders shell bottom navigation bar with 3 tabs and switches tabs', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/crew/profile')) {
          return http.Response(jsonEncode({
            'id': 'c0000000-0000-0000-0000-000000000001',
            'name': 'Drainage Rapid Response Unit Alpha',
            'crewType': 'DRAINAGE',
            'status': 'AVAILABLE',
            'crewLeaderName': 'Sunil Perera',
            'contactNumber': '+94 11 269 1111',
            'description': 'Municipal stormwater drainage division',
          }), 200, headers: {'content-type': 'application/json'});
        }

        if (request.url.path.contains('/crew/work-orders')) {
          return http.Response(jsonEncode({
            'items': [],
            'totalPages': 0,
          }), 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://localhost/api')
        ..token = 'mock-jwt-token';
      final crewService = CrewService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: CrewShellScreen(
            crewService: crewService,
            onLogout: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify bottom navigation items
      expect(find.text('Status & Depot'), findsOneWidget);
      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
      expect(find.byIcon(Icons.assignment_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Tap on Squad Profile tab (index 2)
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Squad Profile'), findsOneWidget);

      // Tap on Mission Queue tab (index 1)
      await tester.tap(find.byIcon(Icons.assignment_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Mission Queue'), findsOneWidget);
    });
  });
}
