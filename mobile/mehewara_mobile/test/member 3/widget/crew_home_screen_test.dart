import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/features/crew/home/crew_home_screen.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') return true;
        if (methodCall.method == 'checkPermission') return 3; // LocationPermission.always
        return null;
      },
    );
  });

  group('CrewHomeScreen Widget Tests (Member 3)', () {
    testWidgets('renders squad identity, readiness badge, and active deployment', (WidgetTester tester) async {
      var navigatedToJobs = false;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/crew/profile')) {
          return http.Response(jsonEncode({
            'id': 'c0000000-0000-0000-0000-000000000001',
            'name': 'Drainage Rapid Response Unit Alpha',
            'crewType': 'DRAINAGE',
            'status': 'AVAILABLE',
            'crewLeaderName': 'Sunil Perera',
            'description': 'Municipal drainage division'
          }), 200, headers: {'content-type': 'application/json'});
        }

        if (request.url.path.contains('/crew/work-orders')) {
          return http.Response(jsonEncode({
            'items': [
              {
                'id': 'wo-1',
                'problemId': 'prob-1',
                'title': 'Clear Central Culvert',
                'problemTitle': 'Galle Road Stormwater Inundation',
                'address': 'Galle Road, Colombo 03',
                'priority': 'HIGH',
                'status': 'IN_PROGRESS',
                'instructions': 'Deploy heavy suction pumps immediately.',
                'createdAt': DateTime.now().toIso8601String(),
              }
            ],
            'totalPages': 1
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
            body: CrewHomeScreen(
              crewService: crewService,
              onNavigateToJobs: () => navigatedToJobs = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify squad identity header
      expect(find.text('Drainage Rapid Response Unit Alpha'), findsOneWidget);

      // Verify crew specialization
      expect(find.textContaining('DRAINAGE'), findsWidgets);

      // Verify active mission card is displayed
      expect(find.text('CURRENT OPERATIONAL MISSION'), findsOneWidget);
      expect(find.text('Galle Road Stormwater Inundation'), findsOneWidget);

      // Tap on the active mission card CTA and verify callback
      final viewDetailsBtn = find.text('View Work Order & Site Details');
      expect(viewDetailsBtn, findsOneWidget);
      await tester.tap(viewDetailsBtn);
      await tester.pumpAndSettle();

      expect(navigatedToJobs, isTrue);
    });
  });
}
