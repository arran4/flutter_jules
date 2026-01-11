import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/activity.dart';

void main() {
  group('Activity Parsing Logic', () {
    late List<Activity> activities;

    setUpAll(() {
      final json = jsonDecode(testActivitiesJson);
      activities = (json['activities'] as List)
          .map((e) => Activity.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('Parses all activities from the list', () {
      expect(activities.length, 11);
    });

    test('Parses Plan Generated activity (02200cce...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '02200cce44f746308651037e4a18caed',
      );
      expect(activity.originator, 'agent');
      expect(activity.planGenerated, isNotNull);
      expect(activity.planGenerated!.plan.steps.length, 5);
      expect(
        activity.planGenerated!.plan.steps[0].title,
        contains('Setup the environment'),
      );
    });

    test('Parses Plan Approved activity (2918fac8...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '2918fac8bc54450a9cbda423b7688413',
      );
      expect(activity.originator, 'user');
      expect(activity.planApproved, isNotNull);
      expect(activity.planApproved!.planId, '5103d604240042cd9f59a4cb2355643a');
    });

    test('Parses Bash Command Output activity (5b3acd1b...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '5b3acd1b3ca2439f9cbaefaccf7f709a',
      );
      expect(activity.progressUpdated, isNotNull);
      expect(activity.artifacts, isNotNull);
      expect(activity.artifacts!.length, 1);

      final artifact = activity.artifacts!.first;
      expect(artifact.bashOutput, isNotNull);
      expect(artifact.bashOutput!.command, contains('npm install'));
      expect(artifact.bashOutput!.output, contains('added 1326 packages'));
    });

    test('Parses Code Modification activity (3a2b4632...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '3a2b46329f894ebea1faf6b8fb956428',
      );
      expect(activity.artifacts, isNotNull);
      final artifact = activity.artifacts!.first;
      expect(artifact.changeSet, isNotNull);
      expect(artifact.changeSet!.source, 'sources/github/bobalover/boba');
      expect(artifact.changeSet!.gitPatch!.baseCommitId, isNotEmpty);
    });

    test('Parses Failed Command activity (10090115...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '100901155a4141d3b37e8e8d2950f3b7',
      );
      final artifact = activity.artifacts!.first;
      expect(artifact.bashOutput, isNotNull);
      expect(artifact.bashOutput!.exitCode, 1);
      expect(
        artifact.bashOutput!.output,
        'Command failed due to an internal error.',
      );
    });

    test('Parses Media Artifact (Frontend Verification) (a76b3535...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == 'a76b35353eda42d09b1c37aedaa56047',
      );
      expect(activity.progressUpdated!.title, 'Frontend verification');

      expect(activity.artifacts, isNotNull);
      expect(activity.artifacts!.length, 1);

      final artifact = activity.artifacts!.first;
      expect(artifact.media, isNotNull);
      expect(artifact.media!.mimeType, 'image/png');
    });

    test('Parses Session Completed activity (022837db...)', () {
      final activity = activities.firstWhere(
        (a) => a.id == '022837dbc0e940eabcc1bc53608e15fc',
      );
      expect(activity.sessionCompleted, isNotNull);

      final artifact = activity.artifacts!.first;
      expect(artifact.changeSet!.gitPatch!.suggestedCommitMessage, isNotNull);
      expect(
        artifact.changeSet!.gitPatch!.suggestedCommitMessage,
        contains('feat: Create simple Boba App'),
      );
    });
  });
}

// Formatted, multi-line JSON for better readability
const testActivitiesJson = r'''
{
  "activities": [
    {
      "name": "sessions/14550388554331055113/activities/02200cce44f746308651037e4a18caed",
      "createTime": "2025-10-03T05:43:42.801654Z",
      "originator": "agent",
      "planGenerated": {
        "plan": {
          "id": "5103d604240042cd9f59a4cb2355643a",
          "createTime": "2025-10-03T05:43:42.801654Z",
          "steps": [
            {
              "id": "705a61fc8ec24a98abc9296a3956fb6b",
              "title": "Setup the environment. I will install the dependencies to run the app.",
              "description": "",
              "index": 0
            },
            {
              "id": "bb5276efad354794a4527e9ad7c0cd42",
              "title": "Modify src/App.js. I will replace the existing React boilerplate with a simple Boba-themed component. This will include a title and a list of boba options.",
              "description": "",
              "index": 1
            },
            {
              "id": "377c9a1c91764dc794a618a06772e3d8",
              "title": "Modify src/App.css. I will update the CSS to provide a fresh, modern look for the Boba app.",
              "description": "",
              "index": 2
            },
            {
              "id": "335802b585b449aeabb855c722cd9c40",
              "title": "Frontend Verification. I will use the frontend_verification_instructions tool to get instructions on how to write a Playwright script to verify the frontend application and generate a screenshot of the changes.",
              "description": "",
              "index": 3
            },
            {
              "id": "3e4cc97c7b2448668d1ac75b8c7b7d69",
              "title": "Submit the changes. Once the app is looking good and verified, I will submit my work.",
              "description": "",
              "index": 4
            }
          ]
        }
      },
      "id": "02200cce44f746308651037e4a18caed"
    },
    {
      "name": "sessions/14550388554331055113/activities/2918fac8bc54450a9cbda423b7688413",
      "createTime": "2025-10-03T05:43:44.954030Z",
      "originator": "user",
      "planApproved": {
        "planId": "5103d604240042cd9f59a4cb2355643a"
      },
      "id": "2918fac8bc54450a9cbda423b7688413"
    },
    {
      "name": "sessions/14550388554331055113/activities/5b3acd1b3ca2439f9cbaefaccf7f709a",
      "createTime": "2025-10-03T05:44:16.700231Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "Ran bash command",
        "description": "Command: \nnpm install\nOutput: added 1326 packages, and audited 1327 packages in 25s\n\n268 packages are looking for fundingExit Code: 0"
      },
      "artifacts": [
        {
          "bashOutput": {
            "command": "\nnpm install",
            "output": "added 1326 packages, and audited 1327 packages in 25s\n\n268 packages are looking for funding",
            "exitCode": 0
          }
        }
      ],
      "id": "5b3acd1b3ca2439f9cbaefaccf7f709a"
    },
    {
      "name": "sessions/14550388554331055113/activities/1ad545d812614a5b84c23a33f6120063",
      "createTime": "2025-10-03T05:44:19.502115Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "I have installed the dependencies using npm install."
      },
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/bobalover/boba",
            "gitPatch": {
              "unidiffPatch": "",
              "baseCommitId": "36ead0a4caefc451b9652ed926a15af9570f4f35",
              "suggestedCommitMessage": ""
            }
          }
        }
      ],
      "id": "1ad545d812614a5b84c23a33f6120063"
    },
    {
      "name": "sessions/14550388554331055113/activities/3a2b46329f894ebea1faf6b8fb956428",
      "createTime": "2025-10-03T05:44:29.265425Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "I have replaced the boilerplate in src/App.js with a Boba-themed component."
      },
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/bobalover/boba",
            "gitPatch": {
              "unidiffPatch": "",
              "baseCommitId": "36ead0a4caefc451b9652ed926a15af9570f4f35",
              "suggestedCommitMessage": ""
            }
          }
        }
      ],
      "id": "3a2b46329f894ebea1faf6b8fb956428"
    },
    {
      "name": "sessions/14550388554331055113/activities/4e8dd66f15e247e3ae5e48eeff89ef47",
      "createTime": "2025-10-03T05:44:37.721013Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "I have updated the CSS in src/App.css to give the app a fresh, modern look."
      },
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/bobalover/boba",
            "gitPatch": {
              "unidiffPatch": "",
              "baseCommitId": "",
              "suggestedCommitMessage": ""
            }
          }
        }
      ],
      "id": "4e8dd66f15e247e3ae5e48eeff89ef47"
    },
    {
      "name": "sessions/14550388554331055113/activities/100901155a4141d3b37e8e8d2950f3b7",
      "createTime": "2025-10-03T05:44:51.048996Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "Ran bash command",
        "description": "Command: \nOutput: Command failed due to an internal error.\nExit Code: 1"
      },
      "artifacts": [
        {
          "bashOutput": {
            "command": "",
            "output": "Command failed due to an internal error.",
            "exitCode": 1
          }
        }
      ],
      "id": "100901155a4141d3b37e8e8d2950f3b7"
    },
    {
      "name": "sessions/14550388554331055113/activities/a76b35353eda42d09b1c37aedaa56047",
      "createTime": "2025-10-03T05:47:49.628363Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "Frontend verification",
        "description": "Agent provided UI verification."
      },
      "artifacts": [
        {
          "media": {
            "data": "",
            "mimeType": "image/png"
          }
        }
      ],
      "id": "a76b35353eda42d09b1c37aedaa56047"
    },
    {
      "name": "sessions/14550388554331055113/activities/db089c7052024cbeb9e37b8c584bc964",
      "createTime": "2025-10-03T05:47:53.669642Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "I have successfully verified the frontend changes by building the app, runnin...",
        "description": "I have successfully verified the frontend changes by building the app, running a Playwright script, and inspecting the resulting screenshot."
      },
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/bobalover/boba",
            "gitPatch": {
              "unidiffPatch": "",
              "baseCommitId": "36ead0a4caefc451b9652ed926a15af9570f4f35"
            }
          }
        }
      ],
      "id": "db089c7052024cbeb9e37b8c584bc964"
    },
    {
      "name": "sessions/14550388554331055113/activities/890e16e30dbb4bf99a92613bdccec212",
      "createTime": "2025-10-03T05:48:14.434427Z",
      "originator": "agent",
      "progressUpdated": {
        "title": "Code reviewed",
        "description": "The user wants to create a \"boba app\". This is a very open-ended request, but the agent's implementation suggests the goal is to create a simple, static web page about boba."
      },
      "id": "890e16e30dbb4bf99a92613bdccec212"
    },
    {
      "name": "sessions/14550388554331055113/activities/022837dbc0e940eabcc1bc53608e15fc",
      "createTime": "2025-10-03T05:48:35.523200Z",
      "originator": "agent",
      "sessionCompleted": {},
      "artifacts": [
        {
          "changeSet": {
            "source": "sources/github/bobalover/boba",
            "gitPatch": {
              "unidiffPatch": "",
              "baseCommitId": "36ead0a4caefc451b9652ed926a15af9570f4f35",
              "suggestedCommitMessage": "feat: Create simple Boba App\n\nThis commit transforms the default Create React App boilerplate into a simple, visually appealing Boba-themed application."
            }
          }
        }
      ],
      "id": "022837dbc0e940eabcc1bc53608e15fc"
    }
  ]
}
''';
