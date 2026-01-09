import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/activity.dart';

void main() {
  test('Activity parsing - agent message without description', () {
    const jsonString = '''
{
  "activities": [
    {
      "name": "sessions/1611661874528033998/activities/0586f72ed78d42cfbd1d0ce5a0fbd53c",
      "createTime": "2025-12-20T12:34:53.104126Z",
      "originator": "agent",
      "agentMessaged": {
        "agentMessage": "Could you please clarify what you mean by 'here' and what you consider a 'meal'? For example, are you referring to a file, a database, or something else?"
      },
      "id": "0586f72ed78d42cfbd1d0ce5a0fbd53c"
    }
  ]
}
''';

    final json = jsonDecode(jsonString);
    final activities = (json['activities'] as List)
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(activities.length, 1);

    final activity = activities[0];
    expect(
      activity.name,
      'sessions/1611661874528033998/activities/0586f72ed78d42cfbd1d0ce5a0fbd53c',
    );
    expect(activity.id, '0586f72ed78d42cfbd1d0ce5a0fbd53c');
    expect(activity.description, ''); // Should default to empty string
    expect(activity.createTime, '2025-12-20T12:34:53.104126Z');
    expect(activity.originator, 'agent');
    expect(activity.agentMessaged, isNotNull);
    expect(activity.agentMessaged!.agentMessage, contains('clarify'));
  });

  test('Parses SessionFailed activity correctly and flags unknown props', () {
    const jsonStr = '''
{
  "name": "sessions/5785130943652494620/activities/a82553a4d3bf4e4f8c2ad49d665d8d11",
  "id": "a82553a4d3bf4e4f8c2ad49d665d8d11",
  "description": "",
  "createTime": "2026-01-09T00:42:13.801699Z",
  "originator": "agent",
  "sessionFailed": {
    "reason": "Jules encountered an error when working on the task."
  },
  "someUnknownProp": "shouldBeFlagged"
}
''';

    final json = jsonDecode(jsonStr);
    final activity = Activity.fromJson(json);

    expect(activity.id, "a82553a4d3bf4e4f8c2ad49d665d8d11");
    expect(activity.sessionFailed, isNotNull);
    expect(
      activity.sessionFailed!.reason,
      "Jules encountered an error when working on the task.",
    );

    expect(activity.unmappedProps.containsKey('someUnknownProp'), true);
    expect(activity.unmappedProps['someUnknownProp'], "shouldBeFlagged");
  });
}
