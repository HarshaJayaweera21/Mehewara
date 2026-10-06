import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

void main() {
  group('CrewService Unit Tests (Member 3)', () {
    test('loads paginated crew work orders and maps their address', () async {
      final requestedPages = <String>[];
      final client = MockClient((request) async {
        requestedPages.add(request.url.queryParameters['page']!);
        expect(request.url.path, '/api/crew/work-orders');
        expect(request.url.queryParameters['pageSize'], '100');
        final page = int.parse(request.url.queryParameters['page']!);
        return http.Response(jsonEncode({
          'items': [
            {
              'id': 'order-$page',
              'problemId': 'problem-$page',
              'title': 'Repair light',
              'problemTitle': 'Broken streetlight',
              'address': 'Main Street',
              'priority': 'HIGH',
              'status': 'ASSIGNED',
            },
          ],
          'totalPages': 2,
        }), 200);
      });
      final apiClient = ApiClient(client: client, baseUrl: 'http://localhost/api')
        ..token = 'test-token';

      final orders = await CrewService(apiClient: apiClient).getCrewWorkOrders();

      expect(requestedPages, ['1', '2']);
      expect(orders.map((order) => order.id), ['order-1', 'order-2']);
      expect(orders.first.problemAddress, 'Main Street');
    });

    test('rejects an unexpected work orders payload', () async {
      final apiClient = ApiClient(
        client: MockClient((_) async => http.Response('[]', 200)),
        baseUrl: 'http://localhost/api',
      )..token = 'test-token';

      expect(
        CrewService(apiClient: apiClient).getCrewWorkOrders(),
        throwsA(isA<ApiException>()),
      );
    });

    test('getCrewProfile returns valid CrewModel on 200 OK', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/crew/profile');
        return http.Response(jsonEncode({
          'id': 'c0000000-0000-0000-0000-000000000001',
          'name': 'Drainage Rapid Response Unit Alpha',
          'crewType': 'DRAINAGE',
          'status': 'AVAILABLE',
          'crewLeaderName': 'Sunil Perera',
          'contactNumber': '+94 11 269 1111',
          'description': 'Stormwater rapid response crew',
        }), 200);
      });

      final apiClient = ApiClient(client: client, baseUrl: 'http://localhost/api')
        ..token = 'test-token';
      final service = CrewService(apiClient: apiClient);

      final profile = await service.getCrewProfile();
      expect(profile.id, 'c0000000-0000-0000-0000-000000000001');
      expect(profile.name, 'Drainage Rapid Response Unit Alpha');
      expect(profile.crewType, 'DRAINAGE');
      expect(profile.status, 'AVAILABLE');
      expect(profile.crewLeaderName, 'Sunil Perera');
    });

    test('updateCrewStatus sends patch and parses updated status', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/crew/status');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'UNAVAILABLE');

        return http.Response(jsonEncode({
          'id': 'c0000000-0000-0000-0000-000000000001',
          'name': 'Drainage Unit Alpha',
          'crewType': 'DRAINAGE',
          'status': 'UNAVAILABLE',
        }), 200);
      });

      final apiClient = ApiClient(client: client, baseUrl: 'http://localhost/api')
        ..token = 'test-token';
      final service = CrewService(apiClient: apiClient);

      final updated = await service.updateCrewStatus('UNAVAILABLE');
      expect(updated.status, 'UNAVAILABLE');
    });
  });
}
