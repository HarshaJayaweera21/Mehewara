import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/models/problem.dart';

void main() {
  group('Problem Model Unit Tests (Member 2)', () {
    test('Problem.fromJson parses all fields and nested relatedReports correctly', () {
      final json = {
        'id': 'b0000000-0000-0000-0000-000000000001',
        'title': 'Severe Road Flooding',
        'description': 'Heavy stormwater covering roadway',
        'category': 'DRAINAGE',
        'latitude': 6.9271,
        'longitude': 79.8612,
        'address': 'Main Galle Road, Colombo',
        'priority': 'HIGH',
        'priorityScore': 85,
        'status': 'IDENTIFIED',
        'reportCount': 2,
        'createdAt': '2026-09-29T10:00:00.000Z',
        'relatedReports': [
          {
            'reportId': 'r0000001',
            'description': 'Drain overflow near school',
            'category': 'DRAINAGE',
            'status': 'PENDING',
            'latitude': 6.9270,
            'longitude': 79.8610,
            'createdAt': '2026-09-29T09:30:00.000Z',
          }
        ]
      };

      final problem = Problem.fromJson(json);

      expect(problem.id, 'b0000000-0000-0000-0000-000000000001');
      expect(problem.title, 'Severe Road Flooding');
      expect(problem.category, 'DRAINAGE');
      expect(problem.latitude, 6.9271);
      expect(problem.longitude, 79.8612);
      expect(problem.priority, 'HIGH');
      expect(problem.priorityScore, 85);
      expect(problem.status, 'IDENTIFIED');
      expect(problem.reportCount, 1);
      expect(problem.relatedReports.length, 1);
      expect(problem.relatedReports.first.reportId, 'r0000001');
      expect(problem.relatedReports.first.description, 'Drain overflow near school');
    });

    test('Problem.fromJson handles missing optional fields with safe defaults', () {
      final minimalJson = {
        'problemId': 'b0000000-0000-0000-0000-000000000002',
        'title': 'Pothole on 2nd Lane',
        'category': 'road',
        'latitude': '6.9150',
        'longitude': '79.8620',
      };

      final problem = Problem.fromJson(minimalJson);

      expect(problem.id, 'b0000000-0000-0000-0000-000000000002');
      expect(problem.title, 'Pothole on 2nd Lane');
      expect(problem.category, 'ROAD');
      expect(problem.latitude, 6.9150);
      expect(problem.longitude, 79.8620);
      expect(problem.description, isNull);
      expect(problem.address, isNull);
      expect(problem.priority, isNull);
      expect(problem.priorityScore, isNull);
      expect(problem.status, 'PENDING');
      expect(problem.relatedReports, isEmpty);
      expect(problem.reportCount, 1);
    });

    test('Problem.toJson serializes all fields into a valid map', () {
      final problem = Problem(
        id: 'p-123',
        title: 'Waste dump',
        category: 'WASTE',
        latitude: 6.9000,
        longitude: 79.8500,
        status: 'IDENTIFIED',
        createdAt: DateTime.parse('2026-09-29T12:00:00.000Z'),
      );

      final json = problem.toJson();

      expect(json['id'], 'p-123');
      expect(json['title'], 'Waste dump');
      expect(json['category'], 'WASTE');
      expect(json['latitude'], 6.9000);
      expect(json['longitude'], 79.8500);
      expect(json['status'], 'IDENTIFIED');
      expect(json['createdAt'], '2026-09-29T12:00:00.000Z');
    });

    test('RelatedReportSummary.fromJson parses report correctly', () {
      final json = {
        'reportId': 'r-999',
        'description': 'Broken pipe',
        'category': 'DRAINAGE',
        'status': 'PROCESSING',
        'latitude': 6.9100,
        'longitude': 79.8200,
        'createdAt': '2026-09-29T11:00:00.000Z',
      };

      final report = RelatedReportSummary.fromJson(json);

      expect(report.reportId, 'r-999');
      expect(report.description, 'Broken pipe');
      expect(report.category, 'DRAINAGE');
      expect(report.status, 'PROCESSING');
      expect(report.latitude, 6.9100);
      expect(report.longitude, 79.8200);
    });
  });
}
