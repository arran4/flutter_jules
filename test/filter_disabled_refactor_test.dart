import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';
import 'package:flutter_jules/models/filter_expression_parser.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/enums.dart'; // SessionState is likely here or in enums
import 'package:flutter_jules/models/cache_metadata.dart';

void main() {
  group('DisabledElement', () {
    test('should serialize and deserialize correctly', () {
      final child = TextElement('foo');
      final disabled = DisabledElement(child);
      final json = disabled.toJson();

      expect(json['type'], 'disabled');
      expect(json['child']['type'], 'text');
      expect(json['child']['text'], 'foo');

      final deserialized = FilterElement.fromJson(json);
      expect(deserialized, isA<DisabledElement>());
      expect((deserialized as DisabledElement).child, isA<TextElement>());
      expect((deserialized.child as TextElement).text, 'foo');
    });

    test('should generate correct expression', () {
      final child = TextElement('foo');
      final disabled = DisabledElement(child);
      expect(disabled.toExpression(), 'DISABLED(TEXT(foo))');
    });

    test('should parse DISABLED expression', () {
      const expression = 'DISABLED(TEXT(foo))';
      final element = FilterExpressionParser.parse(expression);

      expect(element, isA<DisabledElement>());
      expect((element as DisabledElement).child, isA<TextElement>());
      expect((element.child as TextElement).text, 'foo');
    });

    test('should evaluate to implicitIn', () {
      final session = Session(
        id: '1',
        name: 'test',
        prompt: 'test prompt',
        state: SessionState.STATE_UNSPECIFIED,
      );
      final metadata = CacheMetadata.empty();
      final context = FilterContext(session: session, metadata: metadata);

      // A text filter that would definitely match
      final matchChild = TextElement('test');
      final disabledMatch = DisabledElement(matchChild);
      expect(disabledMatch.evaluate(context), FilterState.implicitIn);

      // A text filter that would definitely NOT match
      final noMatchChild = TextElement('nomatch');
      final disabledNoMatch = DisabledElement(noMatchChild);
      expect(disabledNoMatch.evaluate(context), FilterState.implicitIn);
    });
  });

  group('FilterElementBuilder.toggleEnabled', () {
    test('should wrap non-disabled element', () {
      final root = TextElement('foo');
      final newRoot = FilterElementBuilder.toggleEnabled(root, root);

      expect(newRoot, isA<DisabledElement>());
      expect((newRoot as DisabledElement).child, isA<TextElement>());
      expect((newRoot.child as TextElement).text, 'foo');
    });

    test('should unwrap disabled element', () {
      final child = TextElement('foo');
      final root = DisabledElement(child);
      // We pass the DisabledElement itself as target
      final newRoot = FilterElementBuilder.toggleEnabled(root, root);

      expect(newRoot, isA<TextElement>());
      expect((newRoot as TextElement).text, 'foo');
    });

    test('should handle nested toggle', () {
      final child = TextElement('foo');
      final root = AndElement([child, LabelElement('Bar', 'bar')]);

      // Wrap child in disabled
      final newRoot = FilterElementBuilder.toggleEnabled(root, child);

      expect(newRoot, isA<AndElement>());
      final and = newRoot as AndElement;
      expect(and.children[0], isA<DisabledElement>());
      expect((and.children[0] as DisabledElement).child, isA<TextElement>());
      expect(and.children[1], isA<LabelElement>());

      // Unwrap child
      final newRoot2 =
          FilterElementBuilder.toggleEnabled(newRoot, and.children[0]);
      expect(newRoot2, isA<AndElement>());
      final and2 = newRoot2 as AndElement;
      expect(and2.children[0], isA<TextElement>());
    });
  });
}
