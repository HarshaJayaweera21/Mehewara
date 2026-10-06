import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/models/crew_model.dart';

void main() {
  group('CrewModel.fromJson', () {
    test('parses a complete crew payload', () {
      final json = {
        'id': 'crew-1',
        'name': 'Road Crew Alpha',
        'crewType': 'road',
        'status': 'available',
        'crewLeaderUserId': 'user-1',
        'crewLeaderName': 'J. Perera',
        'description': 'Primary road maintenance crew',
        'contactNumber': '+94111111111',
        'activeWorkOrderId': null,
      };

      final crew = CrewModel.fromJson(json);

      expect(crew.id, 'crew-1');
      expect(crew.crewType, 'ROAD');
      expect(crew.status, 'AVAILABLE');
      expect(crew.isAvailable, isTrue);
      expect(crew.isBusy, isFalse);
      expect(crew.isOnDuty, isTrue);
    });

    test('falls back to crewId and crewName and defaults type/status', () {
      final json = {'crewId': 'crew-2', 'crewName': 'Drainage Crew'};

      final crew = CrewModel.fromJson(json);

      expect(crew.id, 'crew-2');
      expect(crew.name, 'Drainage Crew');
      expect(crew.crewType, 'GENERAL');
      expect(crew.status, 'AVAILABLE');
    });

    test('recognizes BUSY and UNAVAILABLE statuses regardless of case', () {
      final busy = CrewModel.fromJson({'id': 'c', 'status': 'Busy'});
      final unavailable = CrewModel.fromJson({'id': 'c', 'status': 'UNAVAILABLE'});

      expect(busy.isBusy, isTrue);
      expect(busy.isOnDuty, isTrue);
      expect(unavailable.isUnavailable, isTrue);
      expect(unavailable.isOnDuty, isFalse);
    });
  });

  group('CrewModel.toJson and copyWith', () {
    test('toJson round-trips the same fields fromJson reads', () {
      final crew = CrewModel.fromJson({
        'id': 'crew-3',
        'name': 'Electrical Crew',
        'crewType': 'electrical',
        'status': 'busy',
        'activeWorkOrderId': 'wo-9',
      });

      final json = crew.toJson();

      expect(json['id'], 'crew-3');
      expect(json['crewType'], 'ELECTRICAL');
      expect(json['status'], 'BUSY');
      expect(json['activeWorkOrderId'], 'wo-9');
    });

    test('copyWith overrides status and activeWorkOrderId while preserving identity fields', () {
      final original = CrewModel.fromJson({
        'id': 'crew-4',
        'name': 'Waste Crew',
        'crewType': 'waste',
        'status': 'available',
      });

      final updated = original.copyWith(status: 'BUSY', activeWorkOrderId: 'wo-10');

      expect(updated.id, original.id);
      expect(updated.name, original.name);
      expect(updated.status, 'BUSY');
      expect(updated.activeWorkOrderId, 'wo-10');
      expect(original.status, 'AVAILABLE'); // original is untouched
    });
  });
}
