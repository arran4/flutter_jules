import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/activity.dart';
import 'package:flutter_jules/ui/widgets/combined_data_viewer.dart';

void main() {
  group('CombinedDataViewer Widget', () {
    testWidgets('should display tabs and data', (WidgetTester tester) async {
      final sessionJson = {
        "name": "sessions/123",
        "id": "123",
        "prompt": "Test Prompt",
        "createTime": "2025-10-03T05:48:35.523200Z",
        "state": "COMPLETED",
      };
      final session = Session.fromJson(sessionJson);

      final activityJson = {
        "name": "sessions/123/activities/456",
        "id": "456",
        "createTime": "2025-10-03T05:48:35.523200Z",
        "description": "Test Activity",
      };
      final activity = Activity.fromJson(activityJson);

      await tester.pumpWidget(
        MaterialApp(
          home: CombinedDataViewer(session: session, activities: [activity]),
        ),
      );

      // Check App Bar Title
      expect(find.text('Session Data'), findsOneWidget);

      // Check Tabs
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);

      // Default tab is Session, check for JSON content
      // SelectableText might split text, but we can search for a substring
      expect(find.textContaining('Test Prompt'), findsOneWidget);

      // Tap on Activities tab
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();

      // Check for activity list item
      expect(find.text('456'), findsOneWidget);
      expect(find.text('Test Activity'), findsOneWidget);
    });
  });
}
