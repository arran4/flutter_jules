import 'package:test/test.dart';
import '../lib/models/filter_element.dart';
import '../lib/models/filter_element_builder.dart';

void main() {
  group('FilterElement.fromJson/toJson', () {
    test('serializes and deserializes a complex tree', () {
      final original = AndElement([
        OrElement([
          PrStatusElement('Open', 'open'),
          PrStatusElement('Draft', 'draft'),
        ]),
        NotElement(LabelElement('Bug', 'bug')),
      ]);

      final json = original.toJson();
      final deserialized = FilterElement.fromJson(json);

      expect(deserialized, isA<AndElement>());
      final and = deserialized as AndElement;
      expect(and.children.length, 2);
      expect(and.children[0], isA<OrElement>());
      expect(and.children[1], isA<NotElement>());
    });
  });

  group('FilterElementBuilder', () {
    test('addFilter combines same-type elements with OR', () {
      var root = FilterElementBuilder.addFilter(null, PrStatusElement('Open', 'open'));
      root = FilterElementBuilder.addFilter(root, PrStatusElement('Draft', 'draft'));
      expect(root, isA<OrElement>());
      expect((root as OrElement).children.length, 2);
    });

    test('addFilter combines different-type elements with AND', () {
      var root = FilterElementBuilder.addFilter(null, PrStatusElement('Open', 'open'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Bug', 'bug'));
      expect(root, isA<AndElement>());
      expect((root as AndElement).children.length, 2);
    });

    test('removeFilter removes an element', () {
      final prOpen = PrStatusElement('Open', 'open');
      final prDraft = PrStatusElement('Draft', 'draft');
      var root = FilterElementBuilder.addFilter(null, prOpen);
      root = FilterElementBuilder.addFilter(root, prDraft);
      root = FilterElementBuilder.removeFilter(root, prOpen);
      expect(root, isA<PrStatusElement>());
      expect((root as PrStatusElement).value, 'draft');
    });

    test('simplify removes redundant nesting', () {
      final prOpen = PrStatusElement('Open', 'open');
      var root = AndElement([OrElement([prOpen])]);
      root = FilterElementBuilder.simplify(root) as AndElement?;
      expect(root, isA<PrStatusElement>());
    });
  });
  group('FilterElement.fromExpression', () {
    test('parses a simple TEXT element', () {
      final result = FilterElement.fromExpression('TEXT(hello)');
      expect(result, isA<TextElement>());
      expect((result as TextElement).text, 'hello');
    });

    test('parses a simple PR element', () {
      final result = FilterElement.fromExpression('PR(open)');
      expect(result, isA<PrStatusElement>());
      expect((result as PrStatusElement).value, 'open');
    });

    test('parses a simple CI element', () {
      final result = FilterElement.fromExpression('CI(success)');
      expect(result, isA<CiStatusElement>());
      expect((result as CiStatusElement).value, 'success');
    });

    test('parses a simple STATE element', () {
      final result = FilterElement.fromExpression('STATE(active)');
      expect(result, isA<StatusElement>());
      expect((result as StatusElement).value, 'active');
    });

    test('parses a simple SOURCE element', () {
      final result = FilterElement.fromExpression('SOURCE(github)');
      expect(result, isA<SourceElement>());
      expect((result as SourceElement).value, 'github');
    });

    test('parses a simple BRANCH element', () {
      final result = FilterElement.fromExpression('BRANCH(main)');
      expect(result, isA<BranchElement>());
      expect((result as BranchElement).value, 'main');
    });

    test('parses a simple LABEL element', () {
      final result = FilterElement.fromExpression('LABEL(bug)');
      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'bug');
    });

    test('parses a simple HASHTAG element', () {
      final result = FilterElement.fromExpression('HASHTAG(urgent)');
      expect(result, isA<TagElement>());
      expect((result as TagElement).value, 'urgent');
    });

    test('parses keyword New()', () {
      final result = FilterElement.fromExpression('New()');
      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'new');
    });

    test('parses keyword Has(PR)', () {
      final result = FilterElement.fromExpression('Has(PR)');
      expect(result, isA<HasPrElement>());
    });

    test('parses keyword Has(Notes)', () {
      final result = FilterElement.fromExpression('Has(Notes)');
      expect(result, isA<HasNotesElement>());
    });

    test('parses keyword Has(Drafts)', () {
      final result = FilterElement.fromExpression('Has(Drafts)');
      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'draft');
    });

    test('parses keyword Has(NoSource)', () {
      final result = FilterElement.fromExpression('Has(NoSource)');
      expect(result, isA<NoSourceElement>());
    });

    test('parses a NOT element', () {
      final result = FilterElement.fromExpression('NOT(PR(open))');
      expect(result, isA<NotElement>());
      expect((result as NotElement).child, isA<PrStatusElement>());
    });

    test('parses an AND element', () {
      final result =
          FilterElement.fromExpression('AND(PR(open) STATE(active))');
      expect(result, isA<AndElement>());
      expect((result as AndElement).children.length, 2);
    });

    test('parses an OR element', () {
      final result = FilterElement.fromExpression('OR(PR(open) PR(draft))');
      expect(result, isA<OrElement>());
      expect((result as OrElement).children.length, 2);
    });

    test('parses a complex nested expression', () {
      final result = FilterElement.fromExpression(
          'AND(OR(PR(open) PR(draft)) NOT(LABEL(bug)))');
      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 2);
      expect(and.children[0], isA<OrElement>());
      expect(and.children[1], isA<NotElement>());
    });

    test('is case-insensitive for keywords', () {
      final result = FilterElement.fromExpression('hAs(pR)');
      expect(result, isA<HasPrElement>());
    });

    test('is case-insensitive for functions', () {
      final result = FilterElement.fromExpression('pr(oPeN)');
      expect(result, isA<PrStatusElement>());
      expect((result as PrStatusElement).value, 'oPeN');
    });

    test('handles quoted strings with spaces', () {
      final result = FilterElement.fromExpression('TEXT((hello world))');
      expect(result, isA<TextElement>());
      expect((result as TextElement).text, 'hello world');
    });

    test('handles multiple elements without a container', () {
      final result = FilterElement.fromExpression('PR(open) STATE(active)');
      expect(result, isA<AndElement>());
      expect((result as AndElement).children.length, 2);
    });

    test('returns a TextElement for unparseable strings', () {
      final result = FilterElement.fromExpression('this is not a valid filter');
      expect(result, isA<TextElement>());
      expect((result as TextElement).text, 'this is not a valid filter');
    });

    test('does not crash on malformed time filter', () {
      final result = FilterElement.fromExpression('UPDATEDBETWEEN(2024-01-01)');
      expect(result, isA<TextElement>());
    });
  });
}
