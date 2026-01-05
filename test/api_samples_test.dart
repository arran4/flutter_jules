import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jules_client/models.dart';

void main() {
  group('API Samples Tests', () {
    test('Parse ListSources Response', () {
      const jsonStr = '''
      { "sources": [ { "name": "sources/github/bobalover/boba", "id": "github/bobalover/boba", "githubRepo": { "owner": "bobalover", "repo": "boba", "isPrivate": false } } ], "nextPageToken": "github/bobalover/boba-web" }
      ''';
      final json = jsonDecode(jsonStr);
      final response = ListSourcesResponse.fromJson(json);

      expect(response.sources.length, 1);
      final source = response.sources.first;
      expect(source.name, "sources/github/bobalover/boba");
      expect(source.id, "github/bobalover/boba");
      expect(source.githubRepo?.owner, "bobalover");
      expect(source.githubRepo?.repo, "boba");
      expect(response.nextPageToken, "github/bobalover/boba-web");
    });

    test('Parse Session Response', () {
      const jsonStr = '''
      { "name": "sessions/31415926535897932384", "id": "31415926535897932384", "title": "Boba App", "sourceContext": { "source": "sources/github/bobalover/boba", "githubRepoContext": { "startingBranch": "main" } }, "prompt": "Create a boba app!" }
      ''';
      final json = jsonDecode(jsonStr);
      final session = Session.fromJson(json);

      expect(session.name, "sessions/31415926535897932384");
      expect(session.id, "31415926535897932384");
      expect(session.title, "Boba App");
      expect(session.sourceContext.source, "sources/github/bobalover/boba");
      expect(session.sourceContext.githubRepoContext?.startingBranch, "main");
      expect(session.prompt, "Create a boba app!");
    });

    test('Parse ListActivities Response', () {
      const jsonStr = '''
      { "activities": [ { "name": "sessions/14550388554331055113/activities/02200cce44f746308651037e4a18caed", "createTime": "2025-10-03T05:43:42.801654Z", "originator": "agent", "planGenerated": { "plan": { "id": "5103d604240042cd9f59a4cb2355643a", "createTime": "2025-10-03T05:43:42.801654Z", "steps": [ { "id": "705a61fc8ec24a98abc9296a3956fb6b", "title": "Setup the environment. I will install the dependencies to run the app.", "description": "...", "index": 0 }, { "id": "bb5276efad354794a4527e9ad7c0cd42", "title": "Modify `src/App.js`.", "description": "...", "index": 1 }, { "id": "377c9a1c91764dc794a618a06772e3d8", "title": "Modify `src/App.css`.", "description": "...", "index": 2 } ] } }, "id": "02200cce44f746308651037e4a18caed" } ] }
      ''';
      final json = jsonDecode(jsonStr);
      // In JulesClient.listActivities logic:
      // final activities = getObjectArrayPropOrDefaultFunction(json, 'activities', Activity.fromJson, () => <Activity>[]);
      // But here we might not have access to that utility directly if it's private or not exported.
      // But Activity.fromJson exists.

      final activitiesList = json['activities'] as List;
      final activities =
          activitiesList.map((e) => Activity.fromJson(e)).toList();

      expect(activities.length, 1);
      final activity = activities.first;
      expect(
        activity.name,
        "sessions/14550388554331055113/activities/02200cce44f746308651037e4a18caed",
      );
      expect(activity.originator, "agent");
      expect(activity.planGenerated, isNotNull);
      expect(activity.planGenerated!.plan.steps.length, 3);
    });
  });
}
