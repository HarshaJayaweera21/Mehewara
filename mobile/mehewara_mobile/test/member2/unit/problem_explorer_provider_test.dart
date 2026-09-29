import 'package:flutter_test/flutter_test.dart';
import 'package:mehewara_mobile/features/resident/problems/problem_explorer_provider.dart';
import 'package:mehewara_mobile/models/problem.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProblemExplorerProvider Tests (Member 2)', () {
    late ProblemExplorerProvider provider;

    final sampleProblems = [
      Problem(
        id: 'p-1',
        title: 'Road Flooding near Central College',
        category: 'DRAINAGE',
        latitude: 6.9271,
        longitude: 79.8612,
        address: 'Main Galle Road',
        status: 'IDENTIFIED',
        createdAt: DateTime.now(),
      ),
      Problem(
        id: 'p-2',
        title: 'Crater Pothole on Baseline Road',
        category: 'ROAD',
        latitude: 6.9150,
        longitude: 79.8700,
        address: 'Baseline Road, Dematagoda',
        status: 'IDENTIFIED',
        createdAt: DateTime.now(),
      ),
      Problem(
        id: 'p-3',
        title: 'Overflowing Garbage Container',
        category: 'WASTE',
        latitude: 6.9100,
        longitude: 79.8550,
        address: 'Ward 4 Market',
        status: 'IDENTIFIED',
        createdAt: DateTime.now(),
      ),
    ];

    setUp(() {
      provider = ProblemExplorerProvider();
      provider.setProblemsForTesting(sampleProblems);
    });

    test('Initial state contains all problems and default map view mode', () {
      expect(provider.problems.length, 3);
      expect(provider.selectedCategory, 'ALL');
      expect(provider.searchQuery, '');
      expect(provider.viewMode, ExplorerViewMode.map);
    });

    test('selectCategory filters problems to matching category only', () {
      provider.selectCategory('DRAINAGE');

      expect(provider.selectedCategory, 'DRAINAGE');
      expect(provider.problems.length, 1);
      expect(provider.problems.first.title, 'Road Flooding near Central College');

      // Reset to ALL
      provider.selectCategory('ALL');
      expect(provider.problems.length, 3);
    });

    test('updateSearch filters problems by title keyword', () {
      provider.updateSearch('pothole');

      expect(provider.problems.length, 1);
      expect(provider.problems.first.title, 'Crater Pothole on Baseline Road');
    });

    test('updateSearch filters problems by address keyword', () {
      provider.updateSearch('dematagoda');

      expect(provider.problems.length, 1);
      expect(provider.problems.first.address, 'Baseline Road, Dematagoda');
    });

    test('setViewMode switches between map and list views', () {
      expect(provider.viewMode, ExplorerViewMode.map);

      provider.setViewMode(ExplorerViewMode.list);
      expect(provider.viewMode, ExplorerViewMode.list);

      provider.setViewMode(ExplorerViewMode.map);
      expect(provider.viewMode, ExplorerViewMode.map);
    });

    test('selectProblem updates the active selected problem', () {
      final targetProblem = sampleProblems[1]; // ROAD pothole
      provider.selectProblem(targetProblem);

      expect(provider.selectedProblem, isNotNull);
      expect(provider.selectedProblem!.id, 'p-2');
      expect(provider.selectedProblem!.title, 'Crater Pothole on Baseline Road');
    });
  });
}
