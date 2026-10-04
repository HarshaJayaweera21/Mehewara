import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mehewara_mobile/core/network/api_client.dart';
import 'package:mehewara_mobile/models/report_model.dart';
import 'package:mehewara_mobile/services/reports/report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'resident-jwt-test'});
    SharedPreferences.setMockInitialValues({'auth_token': 'resident-jwt-test'});
  });

  group('ReportService Unit Tests (Member 1)', () {
    test('createReport sends correct payload to /reports and returns ResidentReport', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/reports') && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'rep-new-1',
              'description': 'Overgrown branches touching power lines.',
              'category': 'ENVIRONMENT',
              'latitude': 6.9271,
              'longitude': 79.8612,
              'address': 'Galle Face Green, Colombo',
              'status': 'PENDING',
              'createdAt': '2026-10-03T07:00:00Z',
              'photos': [
                {
                  'photoId': 'p-1',
                  'photoUrl': 'https://cloudinary.com/photo.jpg',
                  'fileName': 'branch.jpg',
                }
              ],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ApiClient(client: mockClient, baseUrl: 'http://localhost:5194/api');
      final service = ReportService(api: api);

      final report = await service.createReport(
        description: 'Overgrown branches touching power lines.',
        category: 'ENVIRONMENT',
        latitude: 6.9271,
        longitude: 79.8612,
        address: 'Galle Face Green, Colombo',
        photos: const [
          ReportPhoto(id: 'p-1', url: 'https://cloudinary.com/photo.jpg', fileName: 'branch.jpg')
        ],
      );

      expect(requests.length, 1);
      final req = requests.first;
      expect(req.url.path, endsWith('/reports'));
      expect(req.method, 'POST');

      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['description'], 'Overgrown branches touching power lines.');
      expect(body['category'], 'ENVIRONMENT');
      expect(body['latitude'], 6.9271);
      expect(body['longitude'], 79.8612);
      expect(body['address'], 'Galle Face Green, Colombo');
      expect((body['photos'] as List).length, 1);

      expect(report.id, 'rep-new-1');
      expect(report.category, 'ENVIRONMENT');
      expect(report.status, 'PENDING');
      expect(report.photos.length, 1);
    });

    test('getMyReports sends GET to /resident/reports with filters and returns list', () async {
      final requests = <http.Request>[];

      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/resident/reports') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'rep-1',
                  'description': 'Pothole on Main Rd',
                  'category': 'ROAD',
                  'latitude': 6.9,
                  'longitude': 79.8,
                  'status': 'PROCESSING',
                  'createdAt': '2026-10-02T12:00:00Z',
                  'photos': [],
                },
                {
                  'id': 'rep-2',
                  'description': 'Garbage pile near market',
                  'category': 'WASTE',
                  'latitude': 6.91,
                  'longitude': 79.82,
                  'status': 'PENDING',
                  'createdAt': '2026-10-01T12:00:00Z',
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

      final api = ApiClient(client: mockClient, baseUrl: 'http://localhost:5194/api');
      final service = ReportService(api: api);

      final reports = await service.getMyReports(status: 'PROCESSING');

      expect(requests.length, 1);
      final req = requests.first;
      expect(req.url.path, endsWith('/resident/reports'));
      expect(req.url.queryParameters['status'], 'PROCESSING');

      expect(reports.length, 2);
      expect(reports[0].id, 'rep-1');
      expect(reports[0].status, 'PROCESSING');
      expect(reports[1].id, 'rep-2');
      expect(reports[1].category, 'WASTE');
    });

    test('getReport sends GET to /reports/{id} and returns single ResidentReport', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/reports/rep-123')) {
          return http.Response(
            jsonEncode({
              'id': 'rep-123',
              'description': 'Broken water main',
              'category': 'DRAINAGE',
              'latitude': 6.88,
              'longitude': 79.87,
              'status': 'RESOLVED',
              'createdAt': '2026-09-30T09:00:00Z',
              'photos': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ApiClient(client: mockClient, baseUrl: 'http://localhost:5194/api');
      final service = ReportService(api: api);

      final report = await service.getReport('rep-123');
      expect(report.id, 'rep-123');
      expect(report.category, 'DRAINAGE');
      expect(report.status, 'RESOLVED');
    });
  });
}
