import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jules/models/activity.dart';
import 'package:jules/ui/widgets/activity_item.dart';

void main() {
  testWidgets('Renders PlanGenerated activity correctly',
      (WidgetTester tester) async {
    const jsonString = '''
    {
      "name": "sessions/123/activities/456",
      "id": "456",
      "createTime": "2025-10-03T05:43:42.801654Z",
      "planGenerated": {
        "plan": {
          "id": "789",
          "steps": [
            {
              "id": "1",
              "title": "Step 1",
              "description": "Description 1"
            },
            {
              "id": "2",
              "title": "Step 2"
            }
          ]
        }
      }
    }
    ''';

    final activity = Activity.fromJson(jsonDecode(jsonString));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityItem(activity: activity),
      ),
    ));

    expect(find.text('Plan Generated'), findsOneWidget);
    expect(find.text('2 steps'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Description 1'), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
  });

  testWidgets('Renders media artifact correctly', (WidgetTester tester) async {
    const jsonString = '''
    {
      "name": "sessions/123/activities/789",
      "id": "789",
      "createTime": "2025-10-03T05:47:49.628363Z",
      "artifacts": [
        {
          "media": {
            "data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
            "mimeType": "image/png"
          }
        }
      ]
    }
    ''';

    final activity = Activity.fromJson(jsonDecode(jsonString));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityItem(activity: activity),
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Renders changeSet artifact with unidiffPatch correctly',
      (WidgetTester tester) async {
    const jsonString = '''
    {
      "name": "sessions/123/activities/abc",
      "id": "abc",
      "createTime": "2025-10-03T05:44:29.265425Z",
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/test/repo",
            "gitPatch": {
              "unidiffPatch": "--- a/file.txt\\n+++ b/file.txt\\n@@ -1 +1 @@\\n-hello\\n+world"
            }
          }
        }
      ]
    }
    ''';

    final activity = Activity.fromJson(jsonDecode(jsonString));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityItem(activity: activity),
      ),
    ));

    expect(find.text('Change in sources/github/test/repo'), findsOneWidget);
    expect(find.text('--- a/file.txt\n+++ b/file.txt\n@@ -1 +1 @@\n-hello\n+world'),
        findsOneWidget);
  });

  testWidgets('Renders changeSet artifact without gitPatch correctly',
      (WidgetTester tester) async {
    const jsonString = '''
    {
      "name": "sessions/123/activities/def",
      "id": "def",
      "createTime": "2025-10-03T05:44:19.502115Z",
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/test/repo"
          }
        }
      ]
    }
    ''';

    final activity = Activity.fromJson(jsonDecode(jsonString));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivityItem(activity: activity),
      ),
    ));

    expect(find.text('sources/github/test/repo'), findsOneWidget);
  });
}
