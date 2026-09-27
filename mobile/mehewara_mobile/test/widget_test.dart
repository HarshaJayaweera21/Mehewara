import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/main.dart';
import 'package:mehewara_mobile/services/auth/auth_service.dart';
import 'package:mehewara_mobile/services/work_orders/work_order_service.dart';

Map<String, dynamic> job(String status) => {
  'id': 'job-1', 'problemId': 'problem-1', 'crewId': 'crew-1', 'recommendationId': null,
  'crewName': 'Road crew', 'problemTitle': 'Road repair', 'title': 'Repair drain',
  'instructions': 'Clear the drain safely.', 'priority': 'HIGH', 'status': status,
  'latitude': 7.2, 'longitude': 80.6, 'address': 'Main Street',
  'assignedAt': '2026-09-27T10:00:00Z', 'startedAt': null, 'completedAt': null,
  'completionNotes': null, 'createdAt': '2026-09-27T10:00:00Z', 'updatedAt': '2026-09-27T10:00:00Z',
  'history': <dynamic>[],
};
http.Response ok(Object data) => http.Response(jsonEncode(data), 200, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('start has no body; completion notes are optional; bearer token is sent', () async {
    final requests = <http.Request>[];
    final api = ApiClient(client: MockClient((request) async { requests.add(request); return ok(job('COMPLETED')); }))..token = 'test-token';
    final service = WorkOrderService(api);
    await service.start('job-1');
    await service.complete('job-1', '  repaired  ');
    await service.complete('job-1', ' ');
    expect(requests.first.body, isEmpty);
    expect(requests.first.headers['Authorization'], 'Bearer test-token');
    expect(jsonDecode(requests[1].body), {'completionNotes': 'repaired'});
    expect(jsonDecode(requests[2].body), isEmpty);
  });

  test('preserves ownership/conflict error codes and expires authenticated sessions', () async {
    for (final status in [403, 409, 401]) {
      var expired = false;
      final api = ApiClient(client: MockClient((_) async => http.Response(jsonEncode({'error': {'code': 'SERVER_CODE', 'message': 'Server message'}}), status)))..onUnauthorized = () => expired = true;
      await expectLater(api.send('/work-orders/job-1'), throwsA(isA<ApiException>().having((e) => e.status, 'status', status).having((e) => e.code, 'code', 'SERVER_CODE')));
      expect(expired, status == 401);
    }
  });

  test('connection errors become a retryable message', () async {
    final api = ApiClient(client: MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(api.send('/crew/work-orders'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CONNECTION_FAILED')));
  });

  for (final role in crewRoles) {
    testWidgets('$role opens the common My Jobs screen', (tester) async {
      final api = ApiClient(client: MockClient((_) async => ok({'items': [], 'page': 1, 'pageSize': 20, 'totalItems': 0, 'totalPages': 0})));
      final session = CrewSession(api)..restoring = false..user = {'id': role, 'name': 'Crew', 'role': role};
      await tester.pumpWidget(CrewApp(session: session)); await tester.pumpAndSettle();
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('No jobs match this filter.'), findsOneWidget);
    });
  }

  testWidgets('a stale Start reloads the job and allows completion with notes', (tester) async {
    var status = 'ASSIGNED';
    var completed = false;
    final api = ApiClient(client: MockClient((request) async {
      if (request.url.path.endsWith('/start')) {
        status = 'IN_PROGRESS';
        return http.Response(jsonEncode({'error': {'code': 'WORK_ORDER_STATE_CONFLICT', 'message': 'Changed'}}), 409);
      }
      if (request.url.path.endsWith('/complete')) {
        expect(jsonDecode(request.body)['completionNotes'], 'All repaired');
        completed = true; status = 'COMPLETED';
        return ok(job(status));
      }
      if (request.url.path.endsWith('/crew/work-orders')) return ok({'items': [job(status)], 'page': 1, 'pageSize': 20, 'totalItems': 1, 'totalPages': 1});
      return ok(job(status));
    }));
    final session = CrewSession(api)..restoring = false..user = {'id': 'leader', 'name': 'Crew', 'role': 'CREW_LEADER_ROAD'};
    await tester.pumpWidget(CrewApp(session: session)); await tester.pumpAndSettle();
    await tester.tap(find.text('Repair drain')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Job')); await tester.tap(find.text('Start Job')); await tester.pumpAndSettle();
    expect(find.text('This job changed. The latest status has been loaded.'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField)); await tester.enterText(find.byType(TextField), 'All repaired');
    await tester.ensureVisible(find.text('Complete Job')); await tester.tap(find.text('Complete Job')); await tester.pumpAndSettle();
    expect(completed, isTrue); expect(find.text('Complete Job'), findsNothing);
  });

  test('resident login is rejected without storing a crew session', () async {
    final api = ApiClient(client: MockClient((_) async => ok({'accessToken': 'resident-token', 'user': {'id': 'r', 'role': 'RESIDENT'}})));
    final session = CrewSession(api);
    await expectLater(session.login('resident@example.com', 'test'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CREW_ONLY')));
    expect(session.user, isNull); expect(api.token, isNull);
  });
}
