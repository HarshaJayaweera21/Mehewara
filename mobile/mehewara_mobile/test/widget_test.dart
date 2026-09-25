import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/main.dart';

void main() {
  testWidgets('App smoke test - verifies branding', (WidgetTester tester) async {
    await tester.pumpWidget(const MehewaraMobileApp(initialRoute: '/'));
    await tester.pumpAndSettle();

    expect(find.textContaining('MEHEWARA'), findsOneWidget);
  });
}
