import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

void main() {
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
}
