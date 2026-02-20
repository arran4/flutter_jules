import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/ui/widgets/source_metadata_dialog.dart';

void main() {
  testWidgets('SourceMetadataDialog shows source details and raw content', (
    WidgetTester tester,
  ) async {
    final source = Source(
      id: 'test_source',
      name: 'Test Source',
      isArchived: true,
      githubRepo: GitHubRepo(
        owner: 'test_owner',
        repo: 'test_repo',
        isPrivate: true,
        description: 'Test Description',
      ),
      options: {'key': 'value'},
    );

    const rawJson = '{"raw": "data"}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SourceMetadataDialog(source: source, rawContent: rawJson),
        ),
      ),
    );

    // Verify Title
    expect(find.text('Source Metadata'), findsOneWidget);

    // Verify Source Details
    expect(find.text('Test Source'), findsOneWidget);
    expect(find.text('test_source'), findsOneWidget);
    // There are 2 "true" values: Archived, Private (Jules).
    // Private (GitHub) is null in the mock above.
    // However, table rows render keys and values.
    // 'Archived' -> 'true'
    // 'Private (Jules)' -> 'true'
    expect(find.text('true'), findsNWidgets(2));

    // Verify GitHub Details
    expect(find.text('GitHub Repository'), findsOneWidget);
    expect(find.text('test_owner'), findsOneWidget);
    expect(find.text('test_repo'), findsOneWidget);
    expect(find.text('Test Description'), findsOneWidget);

    // Verify Options
    expect(find.text('Options'), findsOneWidget);
    expect(find.textContaining('"key": "value"'), findsOneWidget);

    // Verify Raw Content
    expect(find.text('Raw Content'), findsOneWidget);
    expect(find.textContaining('"raw": "data"'), findsOneWidget);
  });
}
