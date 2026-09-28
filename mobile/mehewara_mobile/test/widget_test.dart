import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/main.dart';

void main() {
  testWidgets('MehewaraApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MehewaraApp());
    expect(find.text('Community Incidents'), findsOneWidget);
  });
}
