import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_expression_parser.dart';
import 'package:flutter_jules/models/time_filter.dart';

void main() {
  group('FilterExpressionParser Function-Style Tests', () {
    test('Should parse functional atoms: New, Hidden, Watching, etc.', () {
      expect(FilterExpressionParser.parse('New()'), isA<LabelElement>());
      expect(FilterExpressionParser.parse('Hidden()'), isA<LabelElement>());
      expect(FilterExpressionParser.parse('Watching()'), isA<LabelElement>());
      expect(FilterExpressionParser.parse('Pending()'), isA<LabelElement>());

      final watching =
          FilterExpressionParser.parse('Watching()') as LabelElement;
      expect(watching.label, 'Watching');
      expect(watching.value, 'watched');
    });

    test('Should parse Has(PR) and Has(Drafts)', () {
      expect(FilterExpressionParser.parse('Has(PR)'), isA<HasPrElement>());

      final drafts =
          FilterExpressionParser.parse('Has(Drafts)') as LabelElement;
      expect(drafts.label, 'Draft');
      expect(drafts.value, 'draft');
    });

    test('Should parse Has(NoSource)', () {
      expect(
        FilterExpressionParser.parse('Has(NoSource)'),
        isA<NoSourceElement>(),
      );
    });

    test('Should strip technical prefixes in State()', () {
      const input1 = 'State(SessionState.IN_PROGRESS)';
      const input2 = 'State(State.COMPLETED)';

      final p1 = FilterExpressionParser.parse(input1) as StatusElement;
      final p2 = FilterExpressionParser.parse(input2) as StatusElement;

      expect(p1.value, 'IN_PROGRESS');
      expect(p2.value, 'COMPLETED');

      // Stability check
      expect(p1.toExpression(), 'State(IN_PROGRESS)');
    });

    test('Should maintain circularity with functional labels', () {
      const input = 'AND(Hidden() New() Has(PR))';
      final parsed = FilterExpressionParser.parse(input);
      expect(parsed, isNotNull);
      expect(parsed!.toExpression(), input);
    });

    test('User case equivalence: complex complex complex', () {
      const input =
          'AND(Hidden() Watching() OR(State(AWAITING_USER_FEEDBACK) State(COMPLETED)) OR(Source(sources/github/arran4/.github) Source(sources/github/arran4/flutter_jules)) New() Pending() Has(PR))';
      final parsed = FilterExpressionParser.parse(input);
      expect(parsed, isNotNull);

      // Since order might depend on how AND is constructed, we'll verify it parses correctly.
      final and = parsed as AndElement;
      // Hidden, Watching, OR, OR, New, Pending, Has(PR)
      expect(and.children.length, 7);

      final output = parsed.toExpression();
      expect(output, contains('Watching()'));
      expect(output, contains('Has(PR)'));
      expect(output, contains('State(AWAITING_USER_FEEDBACK)'));
    });

    test('Backward Compatibility: Watched() -> Watching()', () {
      final parsed = FilterExpressionParser.parse('Watched()');
      expect(parsed, isA<LabelElement>());
      expect(parsed, isA<LabelElement>());
      expect(parsed!.toExpression(), 'Watching()');
    });

    test('Should parse PR() and BRANCH()', () {
      expect(FilterExpressionParser.parse('PR(Draft)'), isA<PrStatusElement>());

      final branch = FilterExpressionParser.parse('Branch(main)');
      expect(branch, isA<BranchElement>());
      expect((branch as BranchElement).value, 'main');
    });

    test('Should parse time-based filters', () {
      final before = FilterExpressionParser.parse('before(yesterday)')
          as TimeFilterElement;
      expect(before.value.type, TimeFilterType.olderThan);
      expect(
        before.value.specificTime?.day,
        DateTime.now().subtract(const Duration(days: 1)).day,
      );

      final after = FilterExpressionParser.parse('after(2023-10-27)')
          as TimeFilterElement;
      expect(after.value.type, TimeFilterType.newerThan);
      expect(after.value.specificTime, DateTime(2023, 10, 27));

      final between =
          FilterExpressionParser.parse('between(2023-10-27, 2023-10-28)')
              as TimeFilterElement;
      expect(between.value.type, TimeFilterType.between);
      expect(between.value.specificTime, DateTime(2023, 10, 27));
      expect(between.value.specificTimeEnd, DateTime(2023, 10, 28));

      final afterDuration = FilterExpressionParser.parse('after(last 24 hours)')
          as TimeFilterElement;
      expect(afterDuration.value.type, TimeFilterType.newerThan);
      expect(
        afterDuration.value.specificTime?.hour,
        DateTime.now().subtract(const Duration(hours: 24)).hour,
      );
    });

    test('Should parse ON(date) filter', () {
      final on =
          FilterExpressionParser.parse('on(2023-10-27)') as TimeFilterElement;
      expect(on.value.type, TimeFilterType.between);
      expect(on.value.specificTime, DateTime(2023, 10, 27));
      expect(on.value.specificTimeEnd, DateTime(2023, 10, 28));
    });
  });
}
