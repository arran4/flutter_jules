import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('FilterElementBuilder Tree Operations Integration', () {
    // Regression Test for "disappearing element"
    test(
      'Move Operation: Should handle identical values by removing only the source instance',
      () {
        // Simulate Move operation:
        // Initial: AND(Source, Target)
        // Users drags Source to Target -> Group OR.
        // Expected Ops:
        // 1. Create SourceCopy.
        // 2. groupFilters(root, target, sourceCopy) -> Replaces Target with OR(Target, SourceCopy).
        //    Tree: AND(Source, OR(Target, SourceCopy)).
        // 3. removeFilter(tree, source) -> Removes Source.
        //    Tree: AND(OR(Target, SourceCopy)).
        // 4. simplify -> OR(Target, SourceCopy).

        final source = PrStatusElement('Draft', 'draft');
        final target = LabelElement('No Approval', 'no_approval');
        final root = AndElement([source, target]);

        // Step 1: Add Copy to Target (Group OR)
        final sourceCopy = PrStatusElement(
          'Draft',
          'draft',
        ); // Identical value, different instance

        // groupFilters replaces target with OR(target, sourceCopy)
        final step1Tree = FilterElementBuilder.groupFilters(
          root,
          target,
          sourceCopy,
          isAnd: false,
        );

        // Verify Step 1 structure
        expect(step1Tree, isA<AndElement>());
        final and1 = step1Tree as AndElement;
        expect(and1.children.length, 2);
        expect(
          and1.children[0],
          equals(source),
        ); // Source should still be there (Identity check)
        expect(and1.children[1], isA<OrElement>());

        final orGroup = and1.children[1] as OrElement;
        expect(orGroup.children[0], equals(target));
        expect(orGroup.children[1], equals(sourceCopy));

        // Step 2: Remove Source (Move operation)
        // This verifies that removeFilter uses Identity, not Value.
        // If it used Value, it would remove BOTH source and sourceCopy (since they have same data).
        final step2Tree = FilterElementBuilder.removeFilter(step1Tree, source);

        // Simplify for final comparison
        final finalTree = FilterElementBuilder.simplify(step2Tree);

        // Verify structure: OR(Target, SourceCopy)
        expect(finalTree, isA<OrElement>());
        final finalOr = finalTree as OrElement;
        expect(finalOr.children.length, 2);
        expect(finalOr.children[0], equals(target));
        expect(finalOr.children[1], equals(sourceCopy));

        // Verify Source is NOT present (by identity)
        expect(finalOr.children, isNot(contains(source)));
      },
    );

    test('Create OR Above (Group with specific logic)', () {
      // AND(Target) -> Group Source into OR Above -> OR(Target, Source)
      final target = LabelElement('A', 'a');
      final source = LabelElement('B', 'b');
      final root = AndElement([target]);

      final newTree = FilterElementBuilder.groupFilters(
        root,
        target,
        source,
        isAnd: false,
      );
      final simplified = FilterElementBuilder.simplify(newTree);

      expect(simplified, isA<OrElement>());
      final or = simplified as OrElement;
      expect(or.children, contains(target));
      expect(or.children, contains(source));
    });

    test('Add to Group (AddFilterToComposite)', () {
      final child1 = LabelElement('A', 'a');
      final targetGroup = OrElement([child1]);
      final root = AndElement([targetGroup]);

      final source = LabelElement('B', 'b');

      final newTree = FilterElementBuilder.addFilterToComposite(
        root,
        targetGroup,
        source,
      );

      expect(newTree, isA<AndElement>());
      final and = newTree as AndElement;
      final or = and.children[0] as OrElement;
      expect(or.children, contains(child1));
      expect(or.children, contains(source));
    });

    test('Toggle NOT using Identity', () {
      final child1 = LabelElement('A', 'a');
      final root = AndElement([child1]);

      // Toggle specific instance
      final newTree = FilterElementBuilder.toggleNot(root, child1);

      expect(newTree, isA<AndElement>());
      final and = newTree as AndElement;
      expect(and.children[0], isA<NotElement>());
      final not = and.children[0] as NotElement;
      expect(not.child, equals(child1));
    });

    test('Context Menu Operation: Add Alternative', () {
      final target = LabelElement('New', 'new');
      final alternative = LabelElement('Updated', 'updated');
      final root = AndElement([target]);

      // Operation simulating 'Add Alternative'
      final newTree = FilterElementBuilder.groupFilters(
        root,
        target,
        alternative,
        isAnd: false,
      );
      final simplified = FilterElementBuilder.simplify(newTree);

      expect(simplified, isA<OrElement>());
      final or = simplified as OrElement;
      expect(or.children, contains(target));
      expect(or.children, contains(alternative));
    });

    test('Context Menu Operation: Toggle NOT Invert/Uninvert', () {
      final a = LabelElement('A', 'a');

      // Invert
      final inverted = FilterElementBuilder.toggleNot(a, a);
      expect(inverted, isA<NotElement>());
      expect((inverted as NotElement).child, equals(a));

      // Uninvert
      final uninverted = FilterElementBuilder.toggleNot(inverted, a);
      expect(uninverted, equals(a));
    });
  });
}
