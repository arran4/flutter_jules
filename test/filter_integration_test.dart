import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/services/cache_service.dart';

void main() {
  group('FilterState Integration Tests', () {
    late List<CachedItem<Session>> testSessions;
    late MockQueueProvider queueProvider;

    setUp(() {
      queueProvider = MockQueueProvider();

      // Create test sessions with various states
      testSessions = [
        // Visible sessions
        CachedItem(
          Session(
            id: 'visible-bug',
            name: 'visible-bug',
            prompt: 'Fix bug',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src1'),
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
            labels: ['Bug'],
          ),
        ),
        CachedItem(
          Session(
            id: 'visible-feature',
            name: 'visible-feature',
            prompt: 'Add feature',
            state: SessionState.COMPLETED,
            sourceContext: SourceContext(source: 'src1'),
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
            labels: ['Feature'],
          ),
        ),
        CachedItem(
          Session(
            id: 'visible-new',
            name: 'visible-new',
            prompt: 'New task',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src2'),
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now().subtract(const Duration(seconds: 5)),
            isHidden: false,
            labels: [],
          ),
        ),
        // Hidden sessions
        CachedItem(
          Session(
            id: 'hidden-bug',
            name: 'hidden-bug',
            prompt: 'Hidden bug',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src1'),
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: true,
            labels: ['Bug'],
          ),
        ),
        CachedItem(
          Session(
            id: 'hidden-feature',
            name: 'hidden-feature',
            prompt: 'Hidden feature',
            state: SessionState.COMPLETED,
            sourceContext: SourceContext(source: 'src1'),
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: true,
            labels: ['Feature'],
          ),
        ),
      ];
    });

    test('No filter: shows only visible items (Implicit In)', () {
      const FilterElement? filterTree = null;

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 3);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'visible-feature', 'visible-new']),
      );
      expect(results.map((r) => r.data.id), isNot(contains('hidden-bug')));
      expect(results.map((r) => r.data.id), isNot(contains('hidden-feature')));
    });

    test('Label(Bug) filter: shows only visible bugs, hides hidden bugs', () {
      final filterTree = LabelElement('Bug', 'bug');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 1);
      expect(results.first.data.id, 'visible-bug');
    });

    test('Hidden() filter: shows only hidden items', () {
      final filterTree = LabelElement('Hidden', 'hidden');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['hidden-bug', 'hidden-feature']),
      );
      expect(results.map((r) => r.data.id), isNot(contains('visible-bug')));
    });

    test('AND(Label(Bug), Hidden()): shows only hidden bugs', () {
      final filterTree = AndElement([
        LabelElement('Bug', 'bug'),
        LabelElement('Hidden', 'hidden'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 1);
      expect(results.first.data.id, 'hidden-bug');
    });

    test('AND(Label(Feature), Hidden()): shows only hidden features', () {
      final filterTree = AndElement([
        LabelElement('Feature', 'feature'),
        LabelElement('Hidden', 'hidden'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 1);
      expect(results.first.data.id, 'hidden-feature');
    });

    test('OR(Label(Bug), Label(Feature)): shows visible bugs and features', () {
      final filterTree = OrElement([
        LabelElement('Bug', 'bug'),
        LabelElement('Feature', 'feature'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'visible-feature']),
      );
    });

    test('OR(Label(Bug), Hidden()): shows visible bugs and all hidden items',
        () {
      final filterTree = OrElement([
        LabelElement('Bug', 'bug'),
        LabelElement('Hidden', 'hidden'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      // visible-bug: Label(Bug) -> Explicit In, Hidden() -> Explicit Out, OR -> Explicit In
      // hidden-bug: Label(Bug) -> Implicit Out, Hidden() -> Explicit In, OR -> Explicit In
      // hidden-feature: Label(Bug) -> Explicit Out, Hidden() -> Explicit In, OR -> Explicit In
      // Result: visible-bug, hidden-bug, hidden-feature
      expect(results.length, 3);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'hidden-bug', 'hidden-feature']),
      );
    });

    test('State(IN_PROGRESS): shows only visible in-progress items', () {
      final filterTree = StatusElement('In Progress', 'IN_PROGRESS');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'visible-new']),
      );
    });

    test(
      'AND(State(IN_PROGRESS), Hidden()): shows hidden in-progress items',
      () {
        final filterTree = AndElement([
          StatusElement('In Progress', 'IN_PROGRESS'),
          LabelElement('Hidden', 'hidden'),
        ]);

        final results = _applyFilter(testSessions, filterTree, queueProvider);

        expect(results.length, 1);
        expect(results.first.data.id, 'hidden-bug');
      },
    );

    test('NOT(Hidden()): shows only visible items (double negative)', () {
      final filterTree = NotElement(LabelElement('Hidden', 'hidden'));

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      // visible items: NOT(Explicit Out) -> Explicit In
      // hidden items: NOT(Explicit In) -> Explicit Out
      expect(results.length, 3);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'visible-feature', 'visible-new']),
      );
    });

    test('NOT(Label(Bug)): shows visible non-bug items', () {
      final filterTree = NotElement(LabelElement('Bug', 'bug'));

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      // visible-bug: Label(Bug) -> Explicit In, NOT -> Explicit Out
      // visible-feature: Label(Bug) -> Explicit Out, NOT -> Explicit In
      // visible-new: Label(Bug) -> Explicit Out, NOT -> Explicit In
      // hidden-bug: Label(Bug) -> Implicit Out, NOT -> Implicit In, AND(Implicit Out, Implicit In) -> Implicit Out (hidden)
      // hidden-feature: Label(Bug) -> Explicit Out, NOT -> Explicit In, AND(Implicit Out, Explicit In) -> Explicit In (visible!)
      expect(results.length, 3);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-feature', 'visible-new', 'hidden-feature']),
      );
      expect(results.map((r) => r.data.id), isNot(contains('visible-bug')));
      expect(results.map((r) => r.data.id), isNot(contains('hidden-bug')));
    });

    test('Source filter: shows only matching visible items', () {
      final filterTree = SourceElement('Source 1', 'src1');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['visible-bug', 'visible-feature']),
      );
    });

    test('AND(Source(src1), Hidden()): shows hidden items from src1', () {
      final filterTree = AndElement([
        SourceElement('Source 1', 'src1'),
        LabelElement('Hidden', 'hidden'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['hidden-bug', 'hidden-feature']),
      );
    });

    test('Complex: AND(OR(Bug, Feature), NOT(State(COMPLETED)))', () {
      final filterTree = AndElement([
        OrElement([
          LabelElement('Bug', 'bug'),
          LabelElement('Feature', 'feature'),
        ]),
        NotElement(StatusElement('Completed', 'COMPLETED')),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      // visible-bug: Bug=Yes, NOT(COMPLETED)=Yes -> Show
      // visible-feature: Feature=Yes, NOT(COMPLETED)=No -> Hide
      expect(results.length, 1);
      expect(results.first.data.id, 'visible-bug');
    });
  });
}

// Helper function that mimics the filtering logic from session_list_screen.dart
List<CachedItem<Session>> _applyFilter(
  List<CachedItem<Session>> items,
  FilterElement? filterTree,
  dynamic queueProvider,
) {
  return items.where((item) {
    final session = item.data;
    final metadata = item.metadata;

    // Apply the FilterState logic
    final initialState =
        metadata.isHidden ? FilterState.implicitOut : FilterState.implicitIn;

    if (filterTree == null) {
      return initialState.isIn;
    }

    final treeResult = filterTree.evaluate(
      FilterContext(
        session: session,
        metadata: metadata,
        queueProvider: queueProvider,
      ),
    );

    final finalState = FilterState.combineAnd(initialState, treeResult);
    return finalState.isIn;
  }).toList();
}

// Mock queue provider for testing
class MockQueueProvider {
  List<dynamic> getDrafts(String sessionId) => [];
}
