import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/core/theme/app_theme.dart';
import 'package:mehewara_mobile/features/resident/report_issue/report_issue_screen.dart';

void main() {
  testWidgets('ReportIssueScreen renders form fields, category chips, and validates inputs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ReportIssueScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify category chips
    expect(find.text('Road'), findsOneWidget);
    expect(find.text('Drainage'), findsOneWidget);
    expect(find.text('Waste'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);
    expect(find.text('Environment'), findsOneWidget);

    // Verify form section headers
    expect(find.text('Tell us what you noticed'), findsOneWidget);
    expect(find.text('Pin the location'), findsOneWidget);

    // Scroll down to submit button
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Submit report'), findsOneWidget);

    // Tap submit button without filling fields
    await tester.tap(find.text('Submit report'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Scroll back up to see validation messages
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify validation errors appear
    expect(find.text('Add a short title (at least 4 characters).'), findsOneWidget);
    expect(find.text('Please enter at least 10 characters.'), findsOneWidget);

    // Select different category chip
    await tester.tap(find.text('Drainage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final drainageChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Drainage'));
    expect(drainageChip.selected, isTrue);
  });
}
