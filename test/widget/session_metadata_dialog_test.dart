import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/ui/widgets/session_metadata_dialog.dart';

void main() {
  testWidgets('SessionMetadataDialog shows raw content when provided',
      (WidgetTester tester) async {
    final session = Session(
      id: 'test_session',
      name: 'Test Session',
      prompt: 'Test Prompt',
    );

    const rawJson = '{"key": "value"}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionMetadataDialog(session: session, rawContent: rawJson),
        ),
      ),
    );

    expect(find.text('Raw Content'), findsOneWidget);
    // SelectableText might render as RichText, but find.text usually works if the text is present.
    // However, with formatting, we need to check if the formatted text is present.
    // The dialog formats the JSON.
    expect(find.textContaining('"key": "value"'), findsOneWidget);
  });

  testWidgets('SessionMetadataDialog shows raw content as-is if invalid JSON',
      (WidgetTester tester) async {
    final session = Session(
      id: 'test_session',
      name: 'Test Session',
      prompt: 'Test Prompt',
    );

    const rawText = 'Not a JSON string';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SessionMetadataDialog(session: session, rawContent: rawText),
        ),
      ),
    );

    expect(find.text('Raw Content'), findsOneWidget);
    expect(find.text(rawText), findsOneWidget);
  });
}
