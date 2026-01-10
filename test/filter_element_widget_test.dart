import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/ui/widgets/filter_element_widget.dart';

void main() {
  group('FilterElementWidget Rendering Coverage', () {
    Future<void> pumpElement(WidgetTester tester, FilterElement element) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilterElementWidget(element: element),
        ),
      ));
    }

    testWidgets('Should render TextElement', (tester) async {
      final element = TextElement('search query');
      await pumpElement(tester, element);

      expect(find.text('search query'), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
    });

    testWidgets('Should render LabelElement', (tester) async {
      final element = LabelElement('Bug', 'bug');
      await pumpElement(tester, element);

      expect(find.text('Bug'), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('Should render StatusElement', (tester) async {
      final element = StatusElement('In Progress', 'IN_PROGRESS');
      await pumpElement(tester, element);

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Should render SourceElement', (tester) async {
      final element = SourceElement('My Source', 'src');
      await pumpElement(tester, element);

      expect(find.text('My Source'), findsOneWidget);
      expect(find.byIcon(Icons.source), findsOneWidget);
    });

    testWidgets('Should render HasPrElement', (tester) async {
      final element = HasPrElement();
      await pumpElement(tester, element);

      expect(find.text('Has PR'), findsOneWidget);
      expect(find.byIcon(Icons.merge), findsOneWidget);
    });

    testWidgets('Should render PrStatusElement', (tester) async {
      // This is the one that was missing
      final element = PrStatusElement('Open', 'open');
      await pumpElement(tester, element);

      expect(find.text('PR: Open'), findsOneWidget);
      expect(find.byIcon(Icons.merge_type), findsOneWidget);
    });

    testWidgets('Should handle redundant prefix in PrStatusElement label',
        (tester) async {
      final element = PrStatusElement('PR: Draft', 'draft');
      await pumpElement(tester, element);

      expect(find.text('PR: Draft'), findsOneWidget);
      expect(find.text('PR: PR: Draft'), findsNothing);
    });

    testWidgets('Should render AndElement (Composite)', (tester) async {
      final element = AndElement([
        TextElement('A'),
        TextElement('B'),
      ]);
      await pumpElement(tester, element);

      expect(find.text('AND'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byIcon(Icons.merge_type), findsOneWidget);
    });

    testWidgets('Should render OrElement (Composite)', (tester) async {
      final element = OrElement([
        TextElement('A'),
        TextElement('B'),
      ]);
      await pumpElement(tester, element);

      expect(find.text('OR'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byIcon(Icons.call_split), findsOneWidget);
    });

    testWidgets('Should render NotElement (Composite)', (tester) async {
      final element = NotElement(TextElement('A'));
      await pumpElement(tester, element);

      expect(find.text('NOT'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });
  });
}
