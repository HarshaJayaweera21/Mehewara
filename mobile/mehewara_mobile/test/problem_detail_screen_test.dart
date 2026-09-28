import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/features/resident/problems/problem_detail_screen.dart';
import 'package:mehewara_mobile/models/problem.dart';

void main() {
  testWidgets('ProblemDetailScreen renders hero card, stepper, and community impact', (tester) async {
    final problem = Problem(
      id: 'b0000000-0000-0000-0000-000000000001',
      title: 'Road Flooding near Central College',
      description: 'Heavy stormwater accumulation covering roadway.',
      category: 'DRAINAGE',
      latitude: 6.9271,
      longitude: 79.8612,
      address: 'Main Galle Road, Ward 4',
      priority: 'HIGH',
      priorityScore: 78,
      status: 'IDENTIFIED',
      reportCount: 4,
      relatedReports: [
        RelatedReportSummary(
          reportId: 'd0000000-0000-0000-0000-000000001047',
          description: 'Heavy water accumulation on street',
          category: 'DRAINAGE',
          status: 'PENDING',
          address: 'Main Galle Road, Ward 4',
          latitude: 6.9271,
          longitude: 79.8612,
          createdAt: DateTime.now().subtract(const Duration(hours: 18)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 18)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProblemDetailScreen(problem: problem),
      ),
    );

    // Verify Title
    expect(find.text('Road Flooding near Central College'), findsOneWidget);

    // Verify Stepper Header
    expect(find.text('Resolution Progress Lifecycle'), findsOneWidget);

    // Verify only the current active stage has ACTIVE text
    expect(find.text('ACTIVE'), findsOneWidget);

    // Verify ETA Today is removed
    expect(find.text('ETA Today'), findsNothing);

    // Verify Community Impact
    expect(find.text('Community Impact'), findsOneWidget);

    // Verify simplified banner text
    expect(find.text('4 residents reported this same issue.'), findsOneWidget);

    // Verify View all is removed
    expect(find.textContaining('View all'), findsNothing);

    // Verify Report item
    expect(find.text('"Heavy water accumulation on street"'), findsOneWidget);
  });
}
