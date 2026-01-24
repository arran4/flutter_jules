import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/activity.dart';
import 'package:flutter_jules/ui/widgets/activity_item.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';

void main() {
  group('ActivityItem Widget', () {
    testWidgets(
        'should display commit message and PR button for ChangeSet with gitPatch',
        (WidgetTester tester) async {
      final activityJson = {
        "name": "sessions/123/activities/456",
        "id": "456",
        "createTime": "2025-10-03T05:48:35.523200Z",
        "originator": "agent",
        "sessionCompleted": {},
        "artifacts": [
          {
            "changeSet": {
              "source": "sources/github/test-owner/test-repo",
              "gitPatch": {
                "unidiffPatch":
                    "--- a/test.txt\n+++ b/test.txt\n@@ -1 +1 @@\n-hello\n+hello world",
                "baseCommitId": "12345",
                "suggestedCommitMessage": "feat: Test commit message"
              }
            }
          }
        ]
      };

      final activity = Activity.fromJson(activityJson);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityItem(activity: activity),
            ),
          ),
        ),
      );

      expect(find.text('Commit Message:'), findsOneWidget);
      expect(find.text('feat: Test commit message'), findsOneWidget);
      expect(find.text('Create PR'), findsOneWidget);
    });

    testWidgets('should display "No Data" for Media artifact with empty data',
        (WidgetTester tester) async {
      final activityJson = {
        "name": "sessions/123/activities/789",
        "id": "789",
        "createTime": "2025-10-03T05:47:49.628363Z",
        "originator": "agent",
        "progressUpdated": {
          "title": "Frontend verification",
          "description": "Agent provided UI verification."
        },
        "artifacts": [
          {
            "media": {"data": "", "mimeType": "image/png"}
          }
        ]
      };

      final activity = Activity.fromJson(activityJson);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ActivityItem(activity: activity)),
          ),
        ),
      );

      expect(find.text('Agent provided UI verification.'), findsOneWidget);
      expect(find.text('Image (image/png) - No Data'), findsOneWidget);
    });

    testWidgets('should display Image widget for Media artifact with data',
        (WidgetTester tester) async {
      final activityJson = {
        "name": "sessions/123/activities/101112",
        "id": "101112",
        "createTime": "2025-10-03T05:47:49.628363Z",
        "originator": "agent",
        "progressUpdated": {
          "title": "Frontend verification",
          "description": "Agent provided UI verification with image."
        },
        "artifacts": [
          {
            "media": {
              // 1x1 transparent PNG
              "data":
                  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
              "mimeType": "image/png"
            }
          }
        ]
      };

      final activity = Activity.fromJson(activityJson);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ActivityItem(activity: activity)),
          ),
        ),
      );

      expect(
        find.text('Agent provided UI verification with image.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
