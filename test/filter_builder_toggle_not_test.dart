import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('FilterElementBuilder Toggle Not', () {
    test('toggleNot should unwrap NotElement when targeted directly', () {
      final child = LabelElement('A', 'a');
      final notElement = NotElement(child);

      // Act: toggleNot called with the NotElement itself as target
      // This happens when user clicks "Remove NOT" on the NotElement pill
      final result = FilterElementBuilder.toggleNot(notElement, notElement);

      // Assert: It should unwrap to child, NOT create double negation
      expect(result, equals(child));
      expect(result, isNot(isA<NotElement>()));
    });
  });
}
