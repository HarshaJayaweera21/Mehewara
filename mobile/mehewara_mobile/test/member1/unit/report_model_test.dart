import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/models/report_model.dart';

void main() {
  group('ResidentReport Model Unit Tests (Member 1)', () {
    test('fromJson parses complete backend report payload correctly', () {
      final json = {
        'id': 'rep-101',
        'title': 'Deep pothole on High Level Road',
        'description': 'Severe crater causing traffic obstruction.\nSecond line detail.',
        'category': 'ROAD',
        'latitude': 6.8722,
        'longitude': 79.8833,
        'address': 'High Level Road, Nugegoda',
        'status': 'PROCESSING',
        'createdAt': '2026-10-01T08:30:00.000Z',
        'photos': [
          {
            'photoId': 'ph-1',
            'photoUrl': 'https://res.cloudinary.com/mehewara/image/upload/sample.jpg',
            'fileName': 'pothole.jpg',
          }
        ],
        'aiAnalysis': 'High severity road surface deformation.',
        'linkedProblemCount': 1,
      };

      final report = ResidentReport.fromJson(json);

      expect(report.id, 'rep-101');
      expect(report.title, 'Deep pothole on High Level Road');
      expect(report.displayTitle, 'Deep pothole on High Level Road');
      expect(report.description, contains('Severe crater'));
      expect(report.category, 'ROAD');
      expect(report.latitude, 6.8722);
      expect(report.longitude, 79.8833);
      expect(report.address, 'High Level Road, Nugegoda');
      expect(report.status, 'PROCESSING');
      expect(report.photos.length, 1);
      expect(report.photos.first.url, 'https://res.cloudinary.com/mehewara/image/upload/sample.jpg');
      expect(report.aiAnalysis, 'High severity road surface deformation.');
      expect(report.linkedProblemCount, 1);
    });

    test('displayTitle falls back to first line of description when title is null or empty', () {
      final jsonNoTitle = {
        'id': 'rep-102',
        'title': null,
        'description': 'Blocked drainage canal causing street overflow after heavy monsoon rain.\nNearby houses flooded.',
        'category': 'DRAINAGE',
        'latitude': 6.9,
        'longitude': 79.9,
        'status': 'PENDING',
        'createdAt': '2026-10-02T10:00:00.000Z',
      };

      final report = ResidentReport.fromJson(jsonNoTitle);
      expect(report.displayTitle, 'Blocked drainage canal causing street overflow after heavy monsoon rain.');
    });

    test('fromJson handles minimal and missing fields with safe defaults', () {
      final jsonMinimal = {
        'id': 'rep-103',
        'description': 'Streetlight flickering',
        'category': 'ELECTRICAL',
      };

      final report = ResidentReport.fromJson(jsonMinimal);
      expect(report.id, 'rep-103');
      expect(report.status, 'PENDING');
      expect(report.latitude, 0.0);
      expect(report.longitude, 0.0);
      expect(report.photos, isEmpty);
      expect(report.linkedProblemCount, 0);
      expect(report.address, isNull);
    });

    test('ReportPhoto parses both id/url and photoId/photoUrl keys', () {
      final photoA = ReportPhoto.fromJson({
        'photoId': 'p-1',
        'photoUrl': 'https://example.com/p1.jpg',
        'fileName': 'img1.png',
      });
      expect(photoA.id, 'p-1');
      expect(photoA.url, 'https://example.com/p1.jpg');
      expect(photoA.fileName, 'img1.png');

      final photoB = ReportPhoto.fromJson({
        'id': 'p-2',
        'url': 'https://example.com/p2.jpg',
      });
      expect(photoB.id, 'p-2');
      expect(photoB.url, 'https://example.com/p2.jpg');
    });

    test('parsedAiAnalysis returns human-readable summary for plain text', () {
      final report = ResidentReport.fromJson({
        'id': 'rep-201',
        'description': 'Pothole on main road',
        'category': 'ROAD',
        'aiAnalysis': 'Severe road surface asphalt depression.',
      });

      final triage = report.parsedAiAnalysis;
      expect(triage, isNotNull);
      expect(triage!.isUncertain, isFalse);
      expect(triage.summary, 'Severe road surface asphalt depression.');
    });

    test('parsedAiAnalysis parses structured multi-agent workflow JSON without raw JSON dump', () {
      const stateData = '''
      {
        "workflow_id": "f0000000-0000-0000-0000-000000000001",
        "structured_report": {
          "observedIssue": "Persistent stormwater accumulation on public road",
          "affectedAsset": "storm drain",
          "inferredCategory": "DRAINAGE",
          "categoryConfidence": 0.92,
          "hazards": ["traffic bottleneck", "pedestrian splash risk"]
        },
        "problem_analysis": {
          "decision": "LINK_EXISTING",
          "summary": "Report consolidated with existing problem Drainage Alpha."
        },
        "priority_analysis": {
          "priority": "HIGH",
          "priorityScore": 75
        }
      }
      ''';

      final report = ResidentReport.fromJson({
        'id': 'rep-202',
        'description': 'Drain blocked near school',
        'category': 'DRAINAGE',
        'aiAnalysis': stateData,
      });

      final triage = report.parsedAiAnalysis;
      expect(triage, isNotNull);
      expect(triage!.isUncertain, isFalse);
      expect(triage.summary, 'Report consolidated with existing problem Drainage Alpha.');
      expect(triage.observedIssue, 'Persistent stormwater accumulation on public road');
      expect(triage.affectedAsset, 'storm drain');
      expect(triage.inferredCategory, 'DRAINAGE');
      expect(triage.categoryConfidence, 0.92);
      expect(triage.priority, 'HIGH');
      expect(triage.hazards, contains('traffic bottleneck'));
      expect(triage.summary.contains('{'), isFalse);
      expect(triage.summary.contains('workflow_id'), isFalse);
    });

    test('parsedAiAnalysis flags UNCERTAIN reports for coordinator verification with clean summary', () {
      const uncertainState = '''
      {
        "workflow_id": "f0000000-0000-0000-0000-000000000002",
        "structured_report": {
          "observedIssue": "Dark transit corridor",
          "affectedAsset": "streetlight",
          "missingInformation": ["exact pole number", "cross street"]
        },
        "problem_analysis": {
          "decision": "UNCERTAIN",
          "summary": "Ambiguous location: GPS coordinates do not align with municipal electrical map grid."
        }
      }
      ''';

      final report = ResidentReport.fromJson({
        'id': 'rep-203',
        'description': 'Streetlight out',
        'category': 'ELECTRICAL',
        'aiAnalysis': uncertainState,
      });

      final triage = report.parsedAiAnalysis;
      expect(triage, isNotNull);
      expect(triage!.isUncertain, isTrue);
      expect(triage.title, 'Flagged for Staff Verification');
      expect(triage.badgeText, 'Coordinator Review');
      expect(triage.summary, contains('Ambiguous location'));
      expect(triage.missingInformation, contains('exact pole number'));
      expect(triage.summary.contains('{'), isFalse);
    });

    test('parsedAiAnalysis safely handles unknown/unexpected JSON without dumping raw text', () {
      const corruptedJson = '{"unknownKey": 12345, "nested": {"foo": "bar"}}';
      final report = ResidentReport.fromJson({
        'id': 'rep-204',
        'description': 'Fallen tree',
        'category': 'ENVIRONMENT',
        'aiAnalysis': corruptedJson,
      });

      final triage = report.parsedAiAnalysis;
      expect(triage, isNotNull);
      expect(triage!.summary.contains('{'), isFalse);
      expect(triage.summary.contains('unknownKey'), isFalse);
      expect(triage.summary, contains('municipal AI service'));
    });
  });
}
