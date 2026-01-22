import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('FilterElementBuilder.toggleEnabled recursive propagation', () {
    test('Should unwrap closest disabled ancestor', () {
      final a = TextElement('A');
      final b = TextElement('B');

      // Structure: DISABLED(AND(A, B))
      // Target: A
      // Expected: AND(A, B)

      final and = AndElement([a, b]);
      final root = DisabledElement(and);

      final result = FilterElementBuilder.toggleEnabled(root, a);

      expect(result, isA<AndElement>());
      final resAnd = result as AndElement;
      expect(resAnd.children.length, 2);
      expect(resAnd.children[0], equals(a));
      expect(resAnd.children[1], equals(b));
    });

    test('Should unwrap closest disabled ancestor when nested', () {
      final a = TextElement('A');
      final b = TextElement('B');

      // Structure: DISABLED(OR(DISABLED(A), B))
      // Target: A
      // Expected: DISABLED(OR(A, B)) -- removes the inner DISABLED

      final innerDisabled = DisabledElement(a);
      final or = OrElement([innerDisabled, b]);
      final root = DisabledElement(or);

      final result = FilterElementBuilder.toggleEnabled(root, a);

      expect(result, isA<DisabledElement>());
      final outer = result as DisabledElement;
      expect(outer.child, isA<OrElement>());
      final resOr = outer.child as OrElement;
      expect(resOr.children[0], equals(a)); // Inner disabled removed
      expect(resOr.children[1], equals(b));
    });

    test(
        'Should unwrap closest disabled ancestor when target is the disabled element',
        () {
      final a = TextElement('A');
      final b = TextElement('B');

      // Structure: DISABLED(AND(A, B))
      // Target: The root DisabledElement
      // Expected: AND(A, B)

      final and = AndElement([a, b]);
      final root = DisabledElement(and);

      final result = FilterElementBuilder.toggleEnabled(root, root);
      expect(result, isA<AndElement>());
    });

    test('Should unwrap closest ancestor even if distant', () {
      final a = TextElement('A');

      // Structure: DISABLED(NOT(NOT(A)))
      // Target: A
      // Expected: NOT(NOT(A))

      final not2 = NotElement(a);
      final not1 = NotElement(not2);
      final root = DisabledElement(not1);

      final result = FilterElementBuilder.toggleEnabled(root, a);

      expect(result, isA<NotElement>());
      expect((result as NotElement).child, isA<NotElement>());
    });

    test('Should disable (wrap) if no disabled ancestor found', () {
      final a = TextElement('A');

      // Structure: A
      // Target: A
      // Expected: DISABLED(A)

      final root = a;
      final result = FilterElementBuilder.toggleEnabled(root, a);

      expect(result, isA<DisabledElement>());
      expect((result as DisabledElement).child, equals(a));
    });
  });
}
