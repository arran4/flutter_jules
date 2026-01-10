import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/filter_element_builder.dart';

void main() {
  group('Filter Grouping Assurance', () {
    // -------------------------------------------------------------------------
    // Standard Grouping (OR)
    // -------------------------------------------------------------------------
    test('Standard Labels (New, Updated, Unread) should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, LabelElement('New', 'new'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Updated', 'updated'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Unread', 'unread'));

      expect(root, isA<OrElement>());
      final or = root as OrElement;
      expect(or.children.length, 3);
      expect(or.children.any((c) => (c as LabelElement).value == 'new'), isTrue);
      expect(or.children.any((c) => (c as LabelElement).value == 'updated'), isTrue);
      expect(or.children.any((c) => (c as LabelElement).value == 'unread'), isTrue);
    });

    test('Statuses should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, StatusElement('Planning', 'PLANNING'));
      root = FilterElementBuilder.addFilter(root, StatusElement('In Progress', 'IN_PROGRESS'));

      expect(root, isA<OrElement>());
      expect((root as OrElement).children.length, 2);
    });

    test('Sources should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, SourceElement('GitHub', 'github'));
      root = FilterElementBuilder.addFilter(root, SourceElement('GitLab', 'gitlab'));

      expect(root, isA<OrElement>());
      expect((root as OrElement).children.length, 2);
    });

    test('Text filters should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, TextElement('foo'));
      root = FilterElementBuilder.addFilter(root, TextElement('bar'));

      expect(root, isA<OrElement>());
      expect((root as OrElement).children.length, 2);
    });

    // -------------------------------------------------------------------------
    // Isolated Grouping (AND)
    // -------------------------------------------------------------------------
    test('Different Types should group with AND (Status + Label)', () {
      var root = FilterElementBuilder.addFilter(null, StatusElement('Active', 'active'));
      root = FilterElementBuilder.addFilter(root, LabelElement('New', 'new'));

      expect(root, isA<AndElement>());
      expect((root as AndElement).children.length, 2);
    });

    test('HasPrElement should be isolated (AND)', () {
      var root = FilterElementBuilder.addFilter(null, LabelElement('New', 'new'));
      root = FilterElementBuilder.addFilter(root, HasPrElement());

      expect(root, isA<AndElement>());
      expect((root as AndElement).children.length, 2);
    });

    // -------------------------------------------------------------------------
    // Specific Isolated Labels
    // -------------------------------------------------------------------------
    test('Draft Label should be isolated (AND) from Standard Labels', () {
      // (Updated OR Unread) AND Draft
      // 'Draft' is now type 'label:queue', 'Updated' is 'label:standard'. Different types -> AND.
      var root = FilterElementBuilder.addFilter(null, LabelElement('Updated', 'updated'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Unread', 'unread')); // -> OR 'label:standard'
      
      root = FilterElementBuilder.addFilter(root, LabelElement('Has Drafts', 'draft')); // -> AND 'label:queue'

      expect(root, isA<AndElement>(), reason: "Queue type (Draft) should be AND'd with Standard type labels");
      final and = root as AndElement;
      
      // Should have 2 children: The OR group (Standard) and the Draft label
      expect(and.children.length, 2);
      expect(and.children.any((c) => c is OrElement), isTrue);
      expect(and.children.any((c) => c is LabelElement && c.value == 'draft'), isTrue);
    });

    test('Queue Labels (Draft, Pending) should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, LabelElement('Has Drafts', 'draft'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Pending', 'pending'));

      expect(root, isA<OrElement>(), reason: "Draft and Pending are both 'label:queue' type and should OR");
      final or = root as OrElement;
      expect(or.children.length, 2);
    });

    test('Hidden Label should be isolated (AND) from other labels', () {
      // (Updated OR Unread) AND Hidden
      var root = FilterElementBuilder.addFilter(null, LabelElement('Updated', 'updated'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Unread', 'unread')); // -> OR
      
      root = FilterElementBuilder.addFilter(root, LabelElement('Hidden', 'hidden')); // -> AND

      expect(root, isA<AndElement>(), reason: "Hidden should be AND'd with the existing label group");
      final and = root as AndElement;
      
      expect(and.children.length, 2);
      expect(and.children.any((c) => c is OrElement), isTrue);
      expect(and.children.any((c) => c is LabelElement && c.value == 'hidden'), isTrue);
    });

    test('Watched Label should be isolated (AND) from other labels', () {
      var root = FilterElementBuilder.addFilter(null, LabelElement('Updated', 'updated'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Watching', 'watched'));

      expect(root, isA<AndElement>());
      expect((root as AndElement).children.length, 2);
    });

     test('Different Isolated Labels should AND with each other', () {
      // Draft (Queue) AND Hidden (Isolated)
      var root = FilterElementBuilder.addFilter(null, LabelElement('Has Drafts', 'draft'));
      root = FilterElementBuilder.addFilter(root, LabelElement('Hidden', 'hidden'));

      expect(root, isA<AndElement>());
      final and = root as AndElement;
      expect(and.children.length, 2);
    });

    test('PR Statuses should group with OR', () {
      var root = FilterElementBuilder.addFilter(null, PrStatusElement('Open', 'Open'));
      root = FilterElementBuilder.addFilter(null, PrStatusElement('Merged', 'Merged')); // Note: creating fresh root for simple OR check
      // Actually let's test adding:
      root = FilterElementBuilder.addFilter(root, PrStatusElement('Open', 'Open')); // Reset
      root = PrStatusElement('Open', 'Open');
      root = FilterElementBuilder.addFilter(root, PrStatusElement('Merged', 'Merged'));

      expect(root, isA<OrElement>());
    });
  });
}
