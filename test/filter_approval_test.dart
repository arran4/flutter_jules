import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/services/cache_service.dart';

void main() {
  group('Approval Filter Tests', () {
    late List<CachedItem<Session>> testSessions;
    late MockQueueProvider queueProvider;

    setUp(() {
      queueProvider = MockQueueProvider();

      testSessions = [
        // Approval required
        CachedItem(
          Session(
            id: 'approval-required-1',
            name: 'approval-required-1',
            prompt: 'Task requiring approval',
            state: SessionState.AWAITING_PLAN_APPROVAL,
            sourceContext: SourceContext(source: 'src1'),
            requirePlanApproval: true,
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
          ),
        ),
        // No approval required
        CachedItem(
          Session(
            id: 'no-approval-1',
            name: 'no-approval-1',
            prompt: 'Task not requiring approval',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src1'),
            requirePlanApproval: false,
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
          ),
        ),
        // Null approval (defaults to false for no_approval filter)
        CachedItem(
          Session(
            id: 'null-approval-1',
            name: 'null-approval-1',
            prompt: 'Task with null approval',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src1'),
            requirePlanApproval: null,
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
          ),
        ),
        // Another approval required
        CachedItem(
          Session(
            id: 'approval-required-2',
            name: 'approval-required-2',
            prompt: 'Another task requiring approval',
            state: SessionState.IN_PROGRESS,
            sourceContext: SourceContext(source: 'src2'),
            requirePlanApproval: true,
          ),
          CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
            isHidden: false,
          ),
        ),
      ];
    });

    test('approval_required filter shows only items requiring approval', () {
      final filterTree = LabelElement('Approval Required', 'approval_required');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['approval-required-1', 'approval-required-2']),
      );
      expect(results.map((r) => r.data.id), isNot(contains('no-approval-1')));
      expect(results.map((r) => r.data.id), isNot(contains('null-approval-1')));
    });

    test('no_approval filter shows items not requiring approval', () {
      final filterTree = LabelElement('No Approval', 'no_approval');

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 2);
      expect(
        results.map((r) => r.data.id),
        containsAll(['no-approval-1', 'null-approval-1']),
      );
      expect(
        results.map((r) => r.data.id),
        isNot(contains('approval-required-1')),
      );
      expect(
        results.map((r) => r.data.id),
        isNot(contains('approval-required-2')),
      );
    });

    test('OR(approval_required, no_approval) shows all items', () {
      final filterTree = OrElement([
        LabelElement('Approval Required', 'approval_required'),
        LabelElement('No Approval', 'no_approval'),
      ]);

      final results = _applyFilter(testSessions, filterTree, queueProvider);

      expect(results.length, 4);
    });

    test(
      'AND(approval_required, State(AWAITING_PLAN_APPROVAL)) shows specific items',
      () {
        final filterTree = AndElement([
          LabelElement('Approval Required', 'approval_required'),
          StatusElement('Awaiting Plan Approval', 'AWAITING_PLAN_APPROVAL'),
        ]);

        final results = _applyFilter(testSessions, filterTree, queueProvider);

        expect(results.length, 1);
        expect(results.first.data.id, 'approval-required-1');
      },
    );
  });
}

// Helper function that mimics the filtering logic
List<CachedItem<Session>> _applyFilter(
  List<CachedItem<Session>> items,
  FilterElement? filterTree,
  dynamic queueProvider,
) {
  return items.where((item) {
    final session = item.data;
    final metadata = item.metadata;

    final initialState = metadata.isHidden
        ? FilterState.implicitOut
        : FilterState.implicitIn;

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
