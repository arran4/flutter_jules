import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('FilterElementBuilder Operations Tests', () {
    test('replaceFilter should replace a node correctly', () {
      final child1 = LabelElement('A', 'a');
      final child2 = LabelElement('B', 'b');
      final root = AndElement([child1, child2]);

      final replacement = LabelElement('C', 'c');
      final newRoot =
          FilterElementBuilder.replaceFilter(root, child1, replacement);

      expect(newRoot, isA<AndElement>());
      final and = newRoot as AndElement;
      expect(and.children[0], equals(replacement));
      expect(and.children[1], equals(child2));
    });

    test('replaceFilter should work on nested nodes', () {
      final child1 = LabelElement('A', 'a');
      final child2 = LabelElement('B', 'b');
      final nested = OrElement([child1, child2]);
      final root = AndElement([nested]);

      final replacement = LabelElement('C', 'c');
      final newRoot =
          FilterElementBuilder.replaceFilter(root, child1, replacement);

      expect(newRoot, isA<AndElement>());
      final and = newRoot as AndElement;
      expect(and.children[0], isA<OrElement>());
      final or = and.children[0] as OrElement;
      expect(or.children[0], equals(replacement));
    });

    test('groupFilters should create grouping', () {
      final child1 = LabelElement('A', 'a');
      final child2 = LabelElement('B', 'b');
      final root = AndElement([child1]); // Root with just child1

      // Group child1 with child2 (OR)
      final newRoot =
          FilterElementBuilder.groupFilters(root, child1, child2, isAnd: false);

      expect(newRoot, isA<AndElement>());
      final and = newRoot as AndElement;
      expect(and.children[0],
          isA<OrElement>()); // Child1 replaced by Or(Child1, Child2)
      final or = and.children[0] as OrElement;
      expect(or.children[0], equals(child1));
      expect(or.children[1], equals(child2));
    });

    test('addFilterToComposite should add to existing composite', () {
      final child1 = LabelElement('A', 'a');
      final composite = OrElement([child1]);
      final root = AndElement([composite]);

      final source = LabelElement('B', 'b');

      final newRoot =
          FilterElementBuilder.addFilterToComposite(root, composite, source);

      expect(newRoot, isA<AndElement>());
      final and = newRoot as AndElement;
      expect(and.children[0], isA<OrElement>());
      final or = and.children[0] as OrElement;
      expect(or.children.length, 2);
      expect(or.children[1], equals(source));
    });
  });
}
