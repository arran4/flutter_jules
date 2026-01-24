import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/time_filter.dart';
import 'package:flutter_jules/ui/widgets/filter_element_widget.dart';

void main() {
  group('FilterElementWidget', () {
    Future<void> pumpElement(WidgetTester tester, FilterElement element) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FilterElementWidget(element: element)),
        ),
      );
    }

    /// Defines the test configuration for each element type.
    /// This map drives the tests and ensures coverage.
    final testCases = <FilterElementType, Function(WidgetTester)>{
      FilterElementType.text: (tester) async {
        const text = 'search query';
        await pumpElement(tester, TextElement(text));
        expect(find.text(text), findsOneWidget);
        expect(find.byIcon(Icons.text_fields), findsOneWidget);
      },
      FilterElementType.label: (tester) async {
        // LabelElement
        await pumpElement(tester, LabelElement('Bug', 'bug'));
        expect(find.text('Bug'), findsOneWidget);
        expect(find.byIcon(Icons.flag), findsOneWidget);
      },
      FilterElementType.status: (tester) async {
        // StatusElement
        await pumpElement(tester, StatusElement('In Progress', 'IN_PROGRESS'));
        expect(find.text('In Progress'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      },
      FilterElementType.source: (tester) async {
        // SourceElement
        await pumpElement(tester, SourceElement('My Source', 'src'));
        expect(find.text('My Source'), findsOneWidget);
        expect(find.byIcon(Icons.source), findsOneWidget);
      },
      FilterElementType.hasPr: (tester) async {
        // HasPrElement
        await pumpElement(tester, HasPrElement());
        expect(find.text('Has PR'), findsOneWidget);
        expect(find.byIcon(Icons.merge), findsOneWidget);
      },
      FilterElementType.prStatus: (tester) async {
        // PrStatusElement
        // Case 1: Simple label
        await pumpElement(tester, PrStatusElement('Open', 'open'));
        expect(find.text('PR: Open'), findsOneWidget);
        expect(find.byIcon(Icons.merge_type), findsOneWidget);

        // Case 2: Redundant prefix regression test
        await pumpElement(tester, PrStatusElement('PR: Draft', 'draft'));
        expect(find.text('PR: Draft'), findsOneWidget);
        expect(find.text('PR: PR: Draft'), findsNothing);
      },
      FilterElementType.ciStatus: (tester) async {
        // CiStatusElement
        // Case 1: Simple label
        await pumpElement(tester, CiStatusElement('Success', 'success'));
        expect(find.text('CI: Success'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // Case 2: Redundant prefix regression test
        await pumpElement(tester, CiStatusElement('CI: Failure', 'failure'));
        expect(find.text('CI: Failure'), findsOneWidget);
        expect(find.text('CI: CI: Failure'), findsNothing);
      },
      FilterElementType.branch: (tester) async {
        // BranchElement
        await pumpElement(tester, BranchElement('main', 'main'));
        expect(find.text('Branch: main'), findsOneWidget);
        expect(find.byIcon(Icons.account_tree), findsOneWidget);
      },
      FilterElementType.time: (tester) async {
        // TimeFilterElement
        final tf = TimeFilter(type: TimeFilterType.newerThan, range: '5 days');
        await pumpElement(tester, TimeFilterElement(tf));
        expect(find.byIcon(Icons.access_time), findsOneWidget);
        expect(find.text('Updated is newer than 5 days'), findsOneWidget);
      },
      FilterElementType.noSource: (tester) async {
        // NoSourceElement
        await pumpElement(tester, NoSourceElement());
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
        expect(find.text('Has No Source'), findsOneWidget);
      },
      FilterElementType.and: (tester) async {
        // AndElement
        await pumpElement(
          tester,
          AndElement([TextElement('A'), TextElement('B')]),
        );
        expect(find.text('AND'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.byIcon(Icons.merge_type), findsOneWidget);
      },
      FilterElementType.or: (tester) async {
        // OrElement
        await pumpElement(
          tester,
          OrElement([TextElement('A'), TextElement('B')]),
        );
        expect(find.text('OR'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.byIcon(Icons.call_split), findsOneWidget);
      },
      FilterElementType.not: (tester) async {
        // NotElement
        await pumpElement(tester, NotElement(TextElement('A')));
        expect(find.text('NOT'), findsOneWidget);
        expect(find.text('A'), findsOneWidget);
        expect(find.byIcon(Icons.block), findsOneWidget);
      },
      FilterElementType.tag: (tester) async {
        // TagElement
        await pumpElement(tester, TagElement('MyTag', 'mytag'));
        expect(find.text('#MyTag'), findsOneWidget);
        expect(find.byIcon(Icons.tag), findsOneWidget);
      },
      FilterElementType.hasNotes: (tester) async {
        // HasNotesElement
        await pumpElement(tester, HasNotesElement());
        expect(find.text('Has Notes'), findsOneWidget);
        expect(find.byIcon(Icons.note), findsOneWidget);
      },
      FilterElementType.disabled: (tester) async {
        // DisabledElement
        await pumpElement(tester, DisabledElement(TextElement('Disabled')));
        expect(find.text('Disabled'), findsOneWidget);
        // We can't easily test opacity, but we can verify text presence
      },
      FilterElementType.hasErrors: (tester) async {
        // HasErrorsElement
        await pumpElement(tester, HasErrorsElement());
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      },
      FilterElementType.hasCreatePr: (tester) async {
        // HasCreatePrElement
        await pumpElement(tester, HasCreatePrElement());
        expect(find.text('Create PR'), findsOneWidget);
        expect(find.byIcon(Icons.add_box), findsOneWidget);
      },
    };

    // 1. SAFETY NET TEST: Ensures no FilterElementType is left behind.
    test(
      'Coverage Assurance: All FilterElementTypes must have a defined test case',
      () {
        final definedTypes = testCases.keys.toSet();
        final allTypes = FilterElementType.values.toSet();
        final missingTypes = allTypes.difference(definedTypes);

        if (missingTypes.isNotEmpty) {
          fail(
            'Rendering logic gap detected! The following types have been defined in the FilterElementType enum '
            'but do not have a corresponding visual test case: $missingTypes.\n'
            'Please add them to the `testCases` map in test/filter_element_widget_test.dart to ensure they are rendered correctly.',
          );
        }
      },
    );

    // 2. DYNAMIC TESTS: Run the verification for each defined type.
    testCases.forEach((type, testLogic) {
      testWidgets('Should render ${type.name} correcty', (tester) async {
        await testLogic(tester);
      });
    });
  });
}
