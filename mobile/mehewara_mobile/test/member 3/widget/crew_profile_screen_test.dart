import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/features/crew/profile/crew_profile_screen.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'email': 'sunil.perera@colombo.gov.lk'});
    SharedPreferences.setMockInitialValues({});
  });

  group('CrewProfileScreen Widget Tests (Member 3)', () {
    testWidgets('renders squad specifications, leader contact info, and hotline', (WidgetTester tester) async {
      var loggedOut = false;

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
            'totalPages': 0
          }), 200, headers: {'content-type': 'application/json'});
        }

        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://localhost/api')
        ..token = 'mock-jwt-token';
      final crewService = CrewService(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrewProfileScreen(
              crewService: crewService,
              onLogout: () => loggedOut = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify crew profile heading
      expect(find.text('Drainage Rapid Response Unit Alpha'), findsOneWidget);

      // Verify leader name
      expect(find.text('Sunil Perera'), findsOneWidget);

      // Verify municipal hotline
      expect(find.text('+94 11 269 1111'), findsWidgets);

      // Verify sign out button
      final signOutBtn = find.text('Sign Out / Switch Account');
      expect(signOutBtn, findsOneWidget);

      await tester.ensureVisible(signOutBtn);
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Confirm sign out in alert dialog
      final confirmBtn = find.widgetWithText(FilledButton, 'Sign Out');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(loggedOut, isTrue);
    });
  });
}
