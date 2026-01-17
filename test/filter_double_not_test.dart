import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('Double NOT Reproduction', () {
    test('Toggle NOT on NotElement should unwrap it (remove NOT)', () {
      final a = LabelElement('A', 'a');
      final notA = NotElement(a);

      // Toggle NOT on the NotElement itself
      final result = FilterElementBuilder.toggleNot(notA, notA);

      // Should be unwrapped
      expect(result, isNot(isA<NotElement>()));
      expect(result, equals(a));
    });

    test('Toggle NOT on NotElement inside composite should unwrap it', () {
      final a = LabelElement('A', 'a');
      final notA = NotElement(a);
      final root = AndElement([notA]);

      // Toggle NOT on the NotElement inside AND
      final result = FilterElementBuilder.toggleNot(root, notA);

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children.length, 1);

      // Should be unwrapped to just A
      expect(and.children[0], equals(a));
      expect(and.children[0], isNot(isA<NotElement>()));
    });

    test('Simplify should squash double NOTs', () {
      final a = LabelElement('A', 'a');
      final doubleNot = NotElement(NotElement(a));

      final result = FilterElementBuilder.simplify(doubleNot);

      expect(result, equals(a));
      expect(result, isNot(isA<NotElement>()));
    });

    test('Simplify should squash double NOTs recursively', () {
      final a = LabelElement('A', 'a');
      // NOT(NOT(A)) inside AND
      final doubleNot = NotElement(NotElement(a));
      final root = AndElement([doubleNot]);

      final result = FilterElementBuilder.simplify(root);

      expect(result, isA<AndElement>());
      final and = result as AndElement;
      expect(and.children[0], equals(a));
    });
  });
}
