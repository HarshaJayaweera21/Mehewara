import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/features/crew/jobs/crew_jobs_screen.dart';
import 'package:mehewara_mobile/models/work_order_model.dart';
import 'package:mehewara_mobile/services/crew_service.dart';

class FakeCrewService extends CrewService {
  FakeCrewService({this.workOrders = const [], this.loadError});

  List<WorkOrderModel> workOrders;
  Object? loadError;
  int startCalls = 0;
  int completeCalls = 0;
  String? lastCompletionNotes;

  @override
  Future<List<WorkOrderModel>> getCrewWorkOrders() async {
    if (loadError != null) throw loadError!;
    return workOrders;
  }

  @override
  Future<WorkOrderModel> startWorkOrder(String workOrderId) async {
    startCalls++;
    return workOrders.first;
  }

  @override
  Future<WorkOrderModel> completeWorkOrder(String workOrderId, String completionNotes) async {
    completeCalls++;
    lastCompletionNotes = completionNotes;
    return workOrders.first;
  }
}

WorkOrderModel buildOrder({
  required String id,
  required String status,
  String priority = 'HIGH',
  int priorityScore = 70,
}) {
  return WorkOrderModel(
    id: id,
    problemId: 'p-$id',
    title: 'Job $id',
    problemTitle: 'Pothole on Main St #$id',
    priority: priority,
    priorityScore: priorityScore,
    status: status,
    createdAt: DateTime(2026, 9, 27),
  );
}

Future<void> pumpScreen(WidgetTester tester, CrewService service) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: CrewJobsScreen(crewService: service))),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CrewJobsScreen', () {
    testWidgets('shows empty states when there are no work orders', (tester) async {
      final service = FakeCrewService(workOrders: []);

      await pumpScreen(tester, service);

      expect(find.text('No Active Mission in Progress'), findsOneWidget);
      expect(find.text('Queue is Empty'), findsOneWidget);
      expect(find.text('No past completed jobs recorded yet.'), findsOneWidget);
    });

    testWidgets('shows an error state with retry when loading fails', (tester) async {
      final service = FakeCrewService(loadError: Exception('Connection failed'));

      await pumpScreen(tester, service);

      expect(find.textContaining('Connection failed'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      service.loadError = null;
      service.workOrders = [buildOrder(id: '1', status: 'ASSIGNED')];
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Pothole on Main St #1'), findsOneWidget);
    });

    testWidgets('renders a queued job with an enabled Start Work Order button when no active mission', (tester) async {
      final service = FakeCrewService(workOrders: [buildOrder(id: '1', status: 'ASSIGNED')]);

      await pumpScreen(tester, service);

      expect(find.text('Start Work Order'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Start Work Order'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('starting a job shows a confirmation dialog and calls the service on confirm', (tester) async {
      final service = FakeCrewService(workOrders: [buildOrder(id: '1', status: 'ASSIGNED')]);

      await pumpScreen(tester, service);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Work Order'));
      await tester.pumpAndSettle();

      expect(find.text('Start Work Order?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Start Job'));
      await tester.pumpAndSettle();

      expect(service.startCalls, 1);
      expect(find.textContaining('is now IN PROGRESS'), findsOneWidget);
    });

    testWidgets('blocks starting a second job while one is already in progress', (tester) async {
      final service = FakeCrewService(workOrders: [
        buildOrder(id: 'active', status: 'IN_PROGRESS'),
        buildOrder(id: 'queued', status: 'ASSIGNED'),
      ]);

      await pumpScreen(tester, service);

      expect(find.text('Locked (Active Mission In Progress)'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Locked (Active Mission In Progress)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Squad already has active mission'), findsOneWidget);
      expect(service.startCalls, 0);
    });

    testWidgets('completion dialog requires at least 5 characters of notes before confirming', (tester) async {
      final service = FakeCrewService(workOrders: [buildOrder(id: 'active', status: 'IN_PROGRESS')]);

      await pumpScreen(tester, service);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Work'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Completion'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter at least 5 characters of completion notes.'), findsOneWidget);
      expect(service.completeCalls, 0);

      await tester.enterText(find.byType(TextFormField), 'Fixed the pothole and resealed the surface');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Completion'));
      await tester.pumpAndSettle();

      expect(service.completeCalls, 1);
      expect(service.lastCompletionNotes, 'Fixed the pothole and resealed the surface');
    });
  });
}
