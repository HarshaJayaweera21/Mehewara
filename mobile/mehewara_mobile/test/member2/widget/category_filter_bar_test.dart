import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/widgets/problems/category_filter_bar.dart';

void main() {
  group('CategoryFilterBar Widget Tests (Member 2)', () {
    testWidgets('Renders all category options and fires callback on tap', (tester) async {
      String selected = 'ALL';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFilterBar(
              selectedCategory: selected,
              totalCount: 15,
              onSelectCategory: (newCategory) {
                selected = newCategory;
              },
            ),
          ),
        ),
      );

      // Verify categories are rendered
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Drainage'), findsOneWidget);
      expect(find.text('Road'), findsOneWidget);

      // Tap Road category
      await tester.tap(find.text('Road'));
      await tester.pumpAndSettle();

      // Verify callback fired
      expect(selected, 'ROAD');
    });
  });
}
