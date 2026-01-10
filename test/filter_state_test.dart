import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';

void main() {
  group('FilterState Logic Tests', () {
    late Session visibleSession;
    late Session hiddenSession;
    late CacheMetadata visibleMetadata;
    late CacheMetadata hiddenMetadata;

    setUp(() {
      visibleSession = Session(
        id: '1',
        name: 'visible',
        prompt: 'test prompt',
        state: SessionState.IN_PROGRESS,
        sourceContext: SourceContext(source: 'src'),
      );
      hiddenSession = Session(
        id: '2',
        name: 'hidden',
        prompt: 'test prompt',
        state: SessionState.IN_PROGRESS,
        sourceContext: SourceContext(source: 'src'),
      );
      visibleMetadata = CacheMetadata(
        firstSeen: DateTime.now(),
        lastRetrieved: DateTime.now(),
        lastUpdated: DateTime.now(),
        isHidden: false,
        labels: ['Bug'],
      );
      hiddenMetadata = CacheMetadata(
        firstSeen: DateTime.now(),
        lastRetrieved: DateTime.now(),
        lastUpdated: DateTime.now(),
        isHidden: true,
        labels: ['Bug'],
      );
    });

    test('Initial States: Non-hidden is Implicit In, Hidden is Implicit Out',
        () {
      final visibleInitial = visibleMetadata.isHidden
          ? FilterState.implicitOut
          : FilterState.implicitIn;
      final hiddenInitial = hiddenMetadata.isHidden
          ? FilterState.implicitOut
          : FilterState.implicitIn;

      expect(visibleInitial, FilterState.implicitIn);
      expect(hiddenInitial, FilterState.implicitOut);
      expect(visibleInitial.isIn, isTrue);
      expect(hiddenInitial.isIn, isFalse);
    });

    test('Explicit trumps Implicit in OR', () {
      // OR(Implicit Out, Explicit In) -> Explicit In wins
      final result = FilterState.combineOr(
          FilterState.implicitOut, FilterState.explicitIn);
      expect(result, FilterState.explicitIn);

      // OR(Implicit In, Explicit Out) -> Explicit Out wins
      final result2 = FilterState.combineOr(
          FilterState.implicitIn, FilterState.explicitOut);
      expect(result2, FilterState.explicitOut);
    });

    test('Only Hidden() can pull from Implicit Out to Explicit In', () {
      final context =
          FilterContext(session: hiddenSession, metadata: hiddenMetadata);

      // Label(Bug) matching a hidden item returns Implicit Out (can't pull it in)
      final labelFilter = LabelElement('Bug', 'bug');
      expect(labelFilter.evaluate(context), FilterState.implicitOut);

      // Hidden() on hidden item returns Explicit In
      final hiddenFilter = LabelElement('Hidden', 'hidden');
      expect(hiddenFilter.evaluate(context), FilterState.explicitIn);
    });

    test('Filter can explicitly exclude hidden item Pulled In by Hidden()', () {
      final context =
          FilterContext(session: hiddenSession, metadata: hiddenMetadata);

      // Label(Feature) DOES NOT match hidden Bug session.
      // Since it's hidden, it returns Explicit Out for mismatch.
      final featureFilter = LabelElement('Feature', 'feature');
      expect(featureFilter.evaluate(context), FilterState.explicitOut);

      // AND(Feature, Hidden) for a hidden Bug session:
      // Feature -> Explicit Out
      // Hidden() -> Explicit In
      // AND -> Tie breaker: Out wins. -> Explicit Out.
      final composite =
          AndElement([featureFilter, LabelElement('Hidden', 'hidden')]);
      expect(composite.evaluate(context), FilterState.explicitOut);
    });

    test('Standard Filter Rules for visible items', () {
      final context =
          FilterContext(session: visibleSession, metadata: visibleMetadata);

      // Label(Bug) on visible item returns Explicit In
      final labelFilter = LabelElement('Bug', 'bug');
      expect(labelFilter.evaluate(context), FilterState.explicitIn);

      // Label(NonExistent) on visible item returns Explicit Out
      final missingFilter = LabelElement('Feature', 'feature');
      expect(missingFilter.evaluate(context), FilterState.explicitOut);
    });

    test('AND(Label(Bug), Hidden()) on hidden Bug', () {
      final context =
          FilterContext(session: hiddenSession, metadata: hiddenMetadata);
      final tree = AndElement([
        LabelElement('Bug', 'bug'),
        LabelElement('Hidden', 'hidden'),
      ]);

      final treeResult = tree.evaluate(context);
      // Label(Bug) matches -> Implicit Out (doesn't pull in, doesn't push out)
      // Hidden() matches -> Explicit In
      // AND -> Explicit In wins priority.
      expect(treeResult, FilterState.explicitIn);

      final finalResult =
          FilterState.combineAnd(FilterState.implicitOut, treeResult);
      expect(finalResult.isIn, isTrue); // Visible!
    });
  });
}
