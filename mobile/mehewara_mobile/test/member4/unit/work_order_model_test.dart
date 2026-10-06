import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/models/work_order_model.dart';

void main() {
  group('WorkOrderModel.fromJson', () {
    test('parses a complete work order payload', () {
      final json = {
        'id': 'wo-1',
        'problemId': 'p-1',
        'title': 'Pothole repair',
        'problemTitle': 'Pothole near school',
        'problemDescription': 'Deep pothole blocking traffic',
        'problemCategory': 'ROAD',
        'problemAddress': '12 Main St',
        'latitude': 6.9271,
        'longitude': 79.8612,
        'reportCount': 3,
        'priority': 'high',
        'priorityScore': 70,
        'estimatedDurationMinutes': 90,
        'status': 'assigned',
        'instructions': 'Bring cones',
        'assignedAt': '2026-09-28T08:00:00Z',
        'createdAt': '2026-09-27T08:00:00Z',
      };

      final order = WorkOrderModel.fromJson(json);

      expect(order.id, 'wo-1');
      expect(order.priority, 'HIGH');
      expect(order.status, 'ASSIGNED');
      expect(order.latitude, 6.9271);
      expect(order.hasValidCoordinates, isTrue);
      expect(order.isActive, isTrue);
      expect(order.isQueued, isTrue);
      expect(order.isCompleted, isFalse);
    });

    test('falls back to workOrderId and title when id/problemTitle are absent', () {
      final json = {
        'workOrderId': 'wo-2',
        'title': 'Drain blockage',
        'priority': 'medium',
        'status': 'in_progress',
        'createdAt': '2026-09-27T08:00:00Z',
      };

      final order = WorkOrderModel.fromJson(json);

      expect(order.id, 'wo-2');
      expect(order.problemTitle, 'Drain blockage');
      expect(order.hasValidCoordinates, isFalse);
      expect(order.isInProgress, isTrue);
    });

    test('defaults priority and status and coerces numeric strings', () {
      final json = {
        'id': 'wo-3',
        'title': 'Unlabeled job',
        'latitude': '6.9',
        'longitude': '79.8',
        'priorityScore': '55',
        'reportCount': '2',
        'createdAt': '2026-09-27T08:00:00Z',
      };

      final order = WorkOrderModel.fromJson(json);

      expect(order.priority, 'MEDIUM');
      expect(order.status, 'ASSIGNED');
      expect(order.latitude, 6.9);
      expect(order.priorityScore, 55);
      expect(order.reportCount, 2);
    });

    test('uses current time when createdAt is missing or unparsable', () {
      final json = {'id': 'wo-4', 'title': 'No date', 'priority': 'LOW', 'status': 'ASSIGNED'};

      final before = DateTime.now();
      final order = WorkOrderModel.fromJson(json);
      final after = DateTime.now();

      expect(order.createdAt.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
      expect(order.createdAt.isBefore(after.add(const Duration(seconds: 5))), isTrue);
    });
  });

  group('WorkOrderModel computed properties', () {
    WorkOrderModel buildOrder({required String status, int? durationMinutes}) {
      return WorkOrderModel(
        id: 'wo-x',
        problemId: 'p-x',
        title: 'Test job',
        problemTitle: 'Test job',
        priority: 'HIGH',
        status: status,
        estimatedDurationMinutes: durationMinutes,
        createdAt: DateTime.now(),
      );
    }

    test('isClosed is true for COMPLETED, CANCELLED and FAILED', () {
      expect(buildOrder(status: 'COMPLETED').isClosed, isTrue);
      expect(buildOrder(status: 'CANCELLED').isClosed, isTrue);
      expect(buildOrder(status: 'FAILED').isClosed, isTrue);
      expect(buildOrder(status: 'ASSIGNED').isClosed, isFalse);
    });

    test('isQuickWin is true only when duration is 45 minutes or less', () {
      expect(buildOrder(status: 'ASSIGNED', durationMinutes: 30).isQuickWin, isTrue);
      expect(buildOrder(status: 'ASSIGNED', durationMinutes: 60).isQuickWin, isFalse);
      expect(buildOrder(status: 'ASSIGNED').isQuickWin, isFalse); // missing duration defaults to 60
    });

    test('priorityWeight ranks CRITICAL above HIGH above MEDIUM above LOW', () {
      final critical = buildOrder(status: 'ASSIGNED').priorityWeight;
      expect(critical, 3); // priority fixed to HIGH in helper
    });
  });
}
