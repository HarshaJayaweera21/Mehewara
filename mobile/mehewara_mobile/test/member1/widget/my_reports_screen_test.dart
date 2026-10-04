import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/core/theme/app_theme.dart';
import 'package:mehewara_mobile/features/resident/reports/my_reports_screen.dart';
import 'package:mehewara_mobile/services/reports/report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'resident-test-token'});
    SharedPreferences.setMockInitialValues({'auth_token': 'resident-test-token'});
  });

  testWidgets('MyReportsScreen displays hero statistics, filter chips, and reports list', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/resident/reports')) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'rep-1',
                'title': 'Clogged stormwater gutter',
                'description': 'Water stagnation and mosquitos after rain.',
                'category': 'DRAINAGE',
                'latitude': 6.92,
                'longitude': 79.86,
                'status': 'PENDING',
                'createdAt': '2026-10-02T10:00:00Z',
                'photos': [],
              },
              {
                'id': 'rep-2',
                'title': 'Damaged transformer fence',
                'description': 'Exposed wiring near school footpath.',
                'category': 'ELECTRICAL',
                'latitude': 6.93,
                'longitude': 79.87,
                'status': 'RESOLVED',
                'createdAt': '2026-10-01T10:00:00Z',
                'photos': [],
              },
            ],
            'page': 1,
            'pageSize': 100,
            'totalItems': 2,
            'totalPages': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final api = ApiClient(client: mockClient, baseUrl: 'http://localhost:5194/api')..token = 'resident-test-token';
    final service = ReportService(api: api);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MyReportsScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Hero card counts
    expect(find.text('My reports'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // Total count 2
    expect(find.text('1'), findsWidgets); // Active count 1, Resolved count 1

    // Verify Filter chips
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'In progress'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Resolved'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Closed'), findsOneWidget);

    // Verify Report cards rendered
    expect(find.text('Clogged stormwater gutter'), findsOneWidget);
    expect(find.text('Damaged transformer fence'), findsOneWidget);

    // Search filter test
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'stormwater');
    await tester.pumpAndSettle();

    expect(find.text('Clogged stormwater gutter'), findsOneWidget);
    expect(find.text('Damaged transformer fence'), findsNothing);
  });
}
