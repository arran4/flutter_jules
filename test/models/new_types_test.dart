import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/activity.dart';
import 'package:flutter_jules/models/session.dart';

void main() {
  group('New Types Tests', () {
    test('ListActivitiesResponse serialization', () {
      final activity = Activity(
        name: 'sessions/1/activities/1',
        id: '1',
        createTime: '2023-01-01T00:00:00Z',
      );
      final response = ListActivitiesResponse(
        activities: [activity],
        nextPageToken: 'token',
      );

      final json = response.toJson();
      expect(json['activities'].length, 1);
      expect(json['nextPageToken'], 'token');
    });

    test('ListActivitiesResponse deserialization', () {
      final json = {
        'activities': [
          {
            'name': 'sessions/1/activities/1',
            'id': '1',
            'createTime': '2023-01-01T00:00:00Z',
          },
        ],
        'nextPageToken': 'token',
      };

      final response = ListActivitiesResponse.fromJson(json);
      expect(response.activities.length, 1);
      expect(response.activities[0].id, '1');
      expect(response.nextPageToken, 'token');
    });

    test('SendMessageRequest serialization', () {
      final request = SendMessageRequest(prompt: 'Hello');
      final json = request.toJson();
      expect(json['prompt'], 'Hello');
    });

    test('SendMessageRequest deserialization', () {
      final json = {'prompt': 'Hello'};
      final request = SendMessageRequest.fromJson(json);
      expect(request.prompt, 'Hello');
    });

    test('SendMessageResponse serialization/deserialization', () {
      final response = SendMessageResponse();
      expect(response.toJson(), isEmpty);

      final fromJson = SendMessageResponse.fromJson({});
      expect(fromJson, isA<SendMessageResponse>());
    });

    test('ApprovePlanRequest serialization/deserialization', () {
      final request = ApprovePlanRequest();
      expect(request.toJson(), isEmpty);

      final fromJson = ApprovePlanRequest.fromJson({});
      expect(fromJson, isA<ApprovePlanRequest>());
    });

    test('ApprovePlanResponse serialization/deserialization', () {
      final response = ApprovePlanResponse();
      expect(response.toJson(), isEmpty);

      final fromJson = ApprovePlanResponse.fromJson({});
      expect(fromJson, isA<ApprovePlanResponse>());
    });
  });
}
