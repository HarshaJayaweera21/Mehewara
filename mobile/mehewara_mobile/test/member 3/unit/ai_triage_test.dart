import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/models/report_model.dart';

void main() {
  group('AI Triage & Assessment Unit Tests (Member 3)', () {
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
      expect(triage.title, 'AI Triage & Assessment');
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
          "priorityScore": 75,
          "requiredCrewType": "DRAINAGE",
          "recommendationReason": "Crew matches DRAINAGE requirement."
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
