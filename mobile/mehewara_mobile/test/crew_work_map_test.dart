import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/features/crew/widgets/crew_work_map.dart';
import 'package:mehewara_mobile/models/work_order_model.dart';
import 'package:mehewara_mobile/services/location_service.dart';

void main() {
  test('CrewLocation fallback values check', () {
    const depot = CrewLocation.defaultDepot;
    expect(depot.latitude, 6.9271);
    expect(depot.longitude, 79.8612);
    expect(depot.isLiveGps, isFalse);
    expect(depot.statusMessage, contains('Municipal Central Depot'));
  });

  testWidgets('CrewWorkMap renders pins for squad and assigned problems', (WidgetTester tester) async {
    final activeOrder = WorkOrderModel(
      id: 'wo-active-1',
      problemId: 'prob-1',
      title: 'Pothole Remediation #1',
      problemTitle: 'Main Street Deep Pothole',
      problemAddress: 'Main St, Colombo 03',
      latitude: 6.9280,
      longitude: 79.8620,
      priority: 'CRITICAL',
      status: 'IN_PROGRESS',
      createdAt: DateTime.now(),
    );

    final queuedOrder = WorkOrderModel(
      id: 'wo-queued-2',
      problemId: 'prob-2',
      title: 'Drainage Clearance #2',
      problemTitle: 'Flooded Canal Inflow',
      problemAddress: 'Canal Road, Colombo 05',
      latitude: 6.9310,
      longitude: 79.8650,
      priority: 'HIGH',
      status: 'ASSIGNED',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CrewWorkMap(
              crewLocation: const CrewLocation(
                latitude: 6.9271,
                longitude: 79.8612,
                isLiveGps: true,
              ),
              inProgressOrder: activeOrder,
              queuedOrders: [queuedOrder],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify map section title and status badge
    expect(find.text('OPERATIONAL FIELD WORK MAP'), findsOneWidget);
    expect(find.text('GPS LIVE'), findsOneWidget);

    // Verify squad marker pin
    expect(find.text('SQUAD'), findsOneWidget);

    // Verify active mission marker pin
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify queued marker pin (#2)
    expect(find.text('#2'), findsOneWidget);

    // Verify active mission card details are displayed
    expect(find.text('Main Street Deep Pothole'), findsOneWidget);
  });
}
