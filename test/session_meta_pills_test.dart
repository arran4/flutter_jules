import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/ui/widgets/session_meta_pills.dart';
import 'package:flutter_jules/models.dart';

void main() {
  testWidgets('SessionMetaPills shows Merged PR status', (
    WidgetTester tester,
  ) async {
    final session = Session(
      name: 'test-session',
      id: '123',
      prompt: 'test prompt',
      sourceContext: SourceContext(source: 'test-source'),
      prStatus: 'Merged',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SessionMetaPills(session: session)),
      ),
    );

    // Verify 'PR: Merged' text is displayed
    expect(find.text('PR: Merged'), findsOneWidget);

    // Verify icon (merge_type is used for Merged)
    expect(find.byIcon(Icons.merge_type), findsOneWidget);
  });

  testWidgets('SessionMetaPills shows Open PR status', (
    WidgetTester tester,
  ) async {
    final session = Session(
      name: 'test-session',
      id: '123',
      prompt: 'test prompt',
      sourceContext: SourceContext(source: 'test-source'),
      prStatus: 'Open',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SessionMetaPills(session: session)),
      ),
    );

    expect(find.text('PR: Open'), findsOneWidget);
    expect(find.byIcon(Icons.merge_type), findsOneWidget);
  });
}
