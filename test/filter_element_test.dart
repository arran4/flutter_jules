import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';
import 'package:flutter_jules/models/search_filter.dart';

void main() {
  group('FilterElement Basic Tests', () {
    test('TextElement creation and JSON', () {
      final element = TextElement('search term');
      expect(element.type, FilterElementType.text);
      expect(element.text, 'search term');

      final json = element.toJson();
      expect(json['type'], 'text');
      expect(json['text'], 'search term');

      final restored = TextElement.fromJson(json);
      expect(restored.text, 'search term');
    });

    test('LabelElement creation and JSON', () {
      final element = LabelElement('Unread', 'unread');
      expect(element.type, FilterElementType.label);
      expect(element.label, 'Unread');
      expect(element.value, 'unread');

      final json = element.toJson();
      final restored = LabelElement.fromJson(json);
      expect(restored.label, 'Unread');
      expect(restored.value, 'unread');
    });

    test('AndElement with children', () {
      final and = AndElement([
        LabelElement('Unread', 'unread'),
        LabelElement('New', 'new'),
      ]);

      expect(and.type, FilterElementType.and);
      expect(and.children.length, 2);

      final json = and.toJson();
      expect(json['type'], 'and');
      expect((json['children'] as List).length, 2);

      final restored = AndElement.fromJson(json);
      expect(restored.children.length, 2);
    });

    test('OrElement with children', () {
      final or = OrElement([
        LabelElement('Unread', 'unread'),
        LabelElement('New', 'new'),
      ]);

      expect(or.type, FilterElementType.or);
      expect(or.children.length, 2);
    });

    test('NotElement wrapping', () {
      final not = NotElement(HasPrElement());
      expect(not.type, FilterElementType.not);

      final json = not.toJson();
      expect(json['type'], 'not');
      expect((json['child'] as Map)['type'], 'has_pr');
    });

    test('Complex nested structure', () {
      final complex = AndElement([
        OrElement([
          LabelElement('Unread', 'unread'),
          LabelElement('New', 'new'),
        ]),
        NotElement(HasPrElement()),
        TextElement('search'),
      ]);

      final json = complex.toJson();
      final restored = FilterElement.fromJson(json);

      expect(restored, isA<AndElement>());
      final andElement = restored as AndElement;
      expect(andElement.children.length, 3);
      expect(andElement.children[0], isA<OrElement>());
      expect(andElement.children[1], isA<NotElement>());
      expect(andElement.children[2], isA<TextElement>());
    });
  });

  group('FilterElementBuilder - Add Tests', () {
    test('Add to empty root', () {
      final result = FilterElementBuilder.addFilter(
        null,
        LabelElement('Unread', 'unread'),
      );

      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'unread');
    });

    test('Add same type creates OR', () {
      final root = LabelElement('Unread', 'unread');
      final result = FilterElementBuilder.addFilter(
        root,
        LabelElement('New', 'new'),
      );

      expect(result, isA<OrElement>());
      final or = result as OrElement;
      expect(or.children.length, 2);
      expect(or.children[0], isA<LabelElement>());
      expect(or.children[1], isA<LabelElement>());
    });

    test('Add to existing OR of same type', () {
      final root = OrElement([
        LabelElement('Unread', 'unread'),
        LabelElement('New', 'new'),
      ]);

      final result = FilterElementBuilder.addFilter(
        root,
        LabelElement('Updated', 'updated'),
      );

      expect(result, isA<OrElement>());
      final or = result as OrElement;
      expect(or.children.length, 3);
    });

    test('Add different type creates AND', () {
      final root = LabelElement('Unread', 'unread');
      final result = FilterElementBuilder.addFilter(
        root,
        StatusElement('Completed', 'COMPLETED'),
      );

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 2);
      expect(and.children[0], isA<LabelElement>());
      expect(and.children[1], isA<StatusElement>());
    });

    test('Add to AND with existing OR group', () {
      final root = AndElement([
        OrElement([
          LabelElement('Unread', 'unread'),
          LabelElement('New', 'new'),
        ]),
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.addFilter(
        root,
        LabelElement('Updated', 'updated'),
      );

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 2);
      expect(and.children[0], isA<OrElement>());
      final or = and.children[0] as OrElement;
      expect(or.children.length, 3); // Unread, New, Updated
    });

    test('Add different type to AND without matching OR', () {
      final root = AndElement([
        LabelElement('Unread', 'unread'),
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.addFilter(
        root,
        StatusElement('Completed', 'COMPLETED'),
      );

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 3);
    });

    test('Adding another text element creates OR', () {
      final root = TextElement('old');
      final result = FilterElementBuilder.addFilter(
        root,
        TextElement('new'),
      );

      expect(result, isA<OrElement>());
      final or = result as OrElement;
      expect(or.children.length, 2);
    });
  });

  group('FilterElementBuilder - Remove Tests', () {
    test('Remove only element returns null', () {
      final root = LabelElement('Unread', 'unread');
      final result = FilterElementBuilder.removeFilter(
        root,
        LabelElement('Unread', 'unread'),
      );

      expect(result, isNull);
    });

    test('Remove from OR reduces to single element', () {
      final root = OrElement([
        LabelElement('Unread', 'unread'),
        LabelElement('New', 'new'),
      ]);

      final result = FilterElementBuilder.removeFilter(
        root,
        LabelElement('New', 'new'),
      );

      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'unread');
    });

    test('Remove from OR with 3+ elements', () {
      final root = OrElement([
        LabelElement('Unread', 'unread'),
        LabelElement('New', 'new'),
        LabelElement('Updated', 'updated'),
      ]);

      final result = FilterElementBuilder.removeFilter(
        root,
        LabelElement('New', 'new'),
      );

      expect(result, isA<OrElement>());
      final or = result as OrElement;
      expect(or.children.length, 2);
    });

    test('Remove from AND reduces correctly', () {
      final root = AndElement([
        LabelElement('Unread', 'unread'),
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.removeFilter(
        root,
        HasPrElement(),
      );

      expect(result, isA<LabelElement>());
    });

    test('Remove from nested structure', () {
      final root = AndElement([
        OrElement([
          LabelElement('Unread', 'unread'),
          LabelElement('New', 'new'),
        ]),
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.removeFilter(
        root,
        LabelElement('New', 'new'),
      );

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 2);
      expect(
          and.children[0], isA<LabelElement>()); // OR reduced to single element
    });
  });

  group('FilterElementBuilder - Toggle NOT Tests', () {
    test('Toggle NOT on simple element', () {
      final root = LabelElement('Unread', 'unread');
      final result = FilterElementBuilder.toggleNot(
        root,
        LabelElement('Unread', 'unread'),
      );

      expect(result, isA<NotElement>());
      final not = result as NotElement;
      expect(not.child, isA<LabelElement>());
    });

    test('Toggle NOT twice returns to original', () {
      final root = LabelElement('Unread', 'unread');
      final wrapped = FilterElementBuilder.toggleNot(
        root,
        LabelElement('Unread', 'unread'),
      );
      final unwrapped = FilterElementBuilder.toggleNot(
        wrapped,
        LabelElement('Unread', 'unread'),
      );

      expect(unwrapped, isA<LabelElement>());
    });

    test('Toggle NOT in nested structure', () {
      final root = AndElement([
        LabelElement('Unread', 'unread'),
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.toggleNot(
        root,
        HasPrElement(),
      );

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children[1], isA<NotElement>());
    });
  });

  group('FilterElementBuilder - Simplify Tests', () {
    test('Simplify empty AND/OR returns null', () {
      final and = AndElement([]);
      final or = OrElement([]);

      expect(FilterElementBuilder.simplify(and), isNull);
      expect(FilterElementBuilder.simplify(or), isNull);
    });

    test('Simplify single-child AND/OR unwraps', () {
      final and = AndElement([LabelElement('Unread', 'unread')]);
      final or = OrElement([LabelElement('New', 'new')]);

      final andResult = FilterElementBuilder.simplify(and);
      final orResult = FilterElementBuilder.simplify(or);

      expect(andResult, isA<LabelElement>());
      expect(orResult, isA<LabelElement>());
    });

    test('Simplify nested structure', () {
      final nested = AndElement([
        OrElement([LabelElement('Unread', 'unread')]), // Will simplify to Label
        HasPrElement(),
      ]);

      final result = FilterElementBuilder.simplify(nested);

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children[0], isA<LabelElement>()); // OR unwrapped
    });
  });

  group('Migration Tests', () {
    test('Migrate single include token', () {
      final tokens = [
        const FilterToken(
          id: 'flag:unread',
          type: FilterType.flag,
          label: 'Unread',
          value: 'unread',
          mode: FilterMode.include,
        ),
      ];

      final result = FilterElementBuilder.fromFilterTokens(tokens);

      expect(result, isA<LabelElement>());
      expect((result as LabelElement).value, 'unread');
    });

    test('Migrate single exclude token', () {
      final tokens = [
        const FilterToken(
          id: 'flag:has_pr',
          type: FilterType.flag,
          label: 'Has PR',
          value: 'has_pr',
          mode: FilterMode.exclude,
        ),
      ];

      final result = FilterElementBuilder.fromFilterTokens(tokens);

      expect(result, isA<NotElement>());
      final not = result as NotElement;
      expect(not.child, isA<HasPrElement>());
    });

    test('Migrate same type tokens to OR', () {
      final tokens = [
        const FilterToken(
          id: 'flag:unread',
          type: FilterType.flag,
          label: 'Unread',
          value: 'unread',
        ),
        const FilterToken(
          id: 'flag:new',
          type: FilterType.flag,
          label: 'New',
          value: 'new',
        ),
      ];

      final result = FilterElementBuilder.fromFilterTokens(tokens);

      expect(result, isA<OrElement>());
      final or = result as OrElement;
      expect(or.children.length, 2);
    });

    test('Migrate different type tokens to AND', () {
      final tokens = [
        const FilterToken(
          id: 'flag:unread',
          type: FilterType.flag,
          label: 'Unread',
          value: 'unread',
        ),
        const FilterToken(
          id: 'status:COMPLETED',
          type: FilterType.status,
          label: 'Completed',
          value: 'COMPLETED',
        ),
      ];

      final result = FilterElementBuilder.fromFilterTokens(tokens);

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 2);
    });

    test('Migrate complex token list', () {
      final tokens = [
        const FilterToken(
          id: 'flag:unread',
          type: FilterType.flag,
          label: 'Unread',
          value: 'unread',
        ),
        const FilterToken(
          id: 'flag:new',
          type: FilterType.flag,
          label: 'New',
          value: 'new',
        ),
        const FilterToken(
          id: 'flag:has_pr',
          type: FilterType.flag,
          label: 'Has PR',
          value: 'has_pr',
          mode: FilterMode.exclude,
        ),
        const FilterToken(
          id: 'status:COMPLETED',
          type: FilterType.status,
          label: 'Completed',
          value: 'COMPLETED',
        ),
      ];

      final result = FilterElementBuilder.fromFilterTokens(tokens);

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 3); // OR(unread, new), NOT(has_pr), status
    });

    test('Convert filter element back to tokens', () {
      final element = AndElement([
        OrElement([
          LabelElement('Unread', 'unread'),
          LabelElement('New', 'new'),
        ]),
        NotElement(HasPrElement()),
      ]);

      final tokens = FilterElementBuilder.toFilterTokens(element);

      expect(tokens.length, 3);
      expect(tokens[0].value, 'unread');
      expect(tokens[0].mode, FilterMode.include);
      expect(tokens[1].value, 'new');
      expect(tokens[1].mode, FilterMode.include);
      expect(tokens[2].value, 'has_pr');
      expect(tokens[2].mode, FilterMode.exclude);
    });

    test('Round-trip migration preserves logic', () {
      final originalTokens = [
        const FilterToken(
          id: 'flag:unread',
          type: FilterType.flag,
          label: 'Unread',
          value: 'unread',
        ),
        const FilterToken(
          id: 'flag:new',
          type: FilterType.flag,
          label: 'New',
          value: 'new',
        ),
      ];

      final element = FilterElementBuilder.fromFilterTokens(originalTokens);
      final backToTokens = FilterElementBuilder.toFilterTokens(element);

      expect(backToTokens.length, 2);
      expect(backToTokens[0].value, 'unread');
      expect(backToTokens[1].value, 'new');
    });
  });

  group('Edge Cases', () {
    test('Empty token list returns null', () {
      final result = FilterElementBuilder.fromFilterTokens([]);
      expect(result, isNull);
    });

    test('Null root with various operations', () {
      expect(
          FilterElementBuilder.removeFilter(null, LabelElement('test', 'test')),
          isNull);
      expect(FilterElementBuilder.toggleNot(null, LabelElement('test', 'test')),
          isNull);
      expect(FilterElementBuilder.simplify(null), isNull);
      expect(FilterElementBuilder.toFilterTokens(null), isEmpty);
    });

    test('Adding text to existing text creates OR', () {
      final root = TextElement('old');
      final result = FilterElementBuilder.addFilter(root, TextElement('new'));

      expect(result, isA<OrElement>());
      expect((result as OrElement).children.length, 2);
    });

    test('Status elements group with OR', () {
      final root = StatusElement('Completed', 'COMPLETED');
      final result = FilterElementBuilder.addFilter(
        root,
        StatusElement('In Progress', 'IN_PROGRESS'),
      );

      expect(result, isA<OrElement>());
    });

    test('Source elements group with OR', () {
      final root = SourceElement('repo1', 'sources/github/repo1');
      final result = FilterElementBuilder.addFilter(
        root,
        SourceElement('repo2', 'sources/github/repo2'),
      );

      expect(result, isA<OrElement>());
    });
  });
}
