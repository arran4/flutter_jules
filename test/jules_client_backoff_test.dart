import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class MockBackoffClient extends http.BaseClient {
  final List<http.Response> responses;
  int _requestCount = 0;
  final List<String> logs;

  MockBackoffClient(this.responses, this.logs);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    logs.add('Request ${_requestCount + 1}');
    if (_requestCount < responses.length) {
      final response = responses[_requestCount++];
      return http.StreamedResponse(
        Stream.fromIterable([response.bodyBytes]),
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(Stream.fromIterable([]), 500);
  }
}

void main() {
  test('JulesClient retries on 429 with Retry-After (seconds)', () {
    fakeAsync((async) {
      final logs = <String>[];
      final client = JulesClient(
        client: MockBackoffClient([
          http.Response(
            'Too Many Requests',
            429,
            headers: {'retry-after': '1'},
          ),
          http.Response(
            '{"name": "session1", "id": "session1", "prompt": "test"}',
            200,
          ),
        ], logs),
        baseUrl: 'http://example.com',
      );

      client.getSession('session1').then((session) {
        expect(session.name, 'session1');
      });

      // Should have made first request
      async.flushMicrotasks();
      expect(
        logs.length,
        1,
        reason: 'First request should be made immediately',
      );

      // Advance time by 0.5s (should wait 1s)
      async.elapse(const Duration(milliseconds: 500));
      expect(
        logs.length,
        1,
        reason: 'Should wait for retry-after before second request',
      );

      // Advance time to 1.1s
      async.elapse(const Duration(milliseconds: 600));
      expect(
        logs.length,
        2,
        reason: 'Second request should be made after retry-after',
      );
    });
  });

  test(
    'JulesClient retries on 429 with exponential backoff when no Retry-After',
    () {
      fakeAsync((async) {
        final logs = <String>[];
        final client = JulesClient(
          client: MockBackoffClient([
            http.Response('Too Many Requests', 429),
            http.Response('Too Many Requests', 429),
            http.Response(
              '{"name": "session1", "id": "session1", "prompt": "test"}',
              200,
            ),
          ], logs),
          baseUrl: 'http://example.com',
        );

        client.getSession('session1').then((session) {
          expect(session.name, 'session1');
        });

        async.flushMicrotasks();
        expect(logs.length, 1, reason: 'First request');

        // Assume initial backoff is 1s.
        async.elapse(const Duration(milliseconds: 500));
        expect(logs.length, 1, reason: 'Should wait for backoff');

        async.elapse(const Duration(milliseconds: 600)); // Total 1.1s
        expect(logs.length, 2, reason: 'Second request after 1s');

        // Next backoff should be larger (e.g. 2s)
        async.elapse(
          const Duration(seconds: 1),
        ); // Total 2.1s from start. 1s from 2nd req.
        expect(logs.length, 2, reason: 'Should wait for larger backoff');

        async.elapse(const Duration(seconds: 2)); // Total 4.1s from start.
        expect(logs.length, 3, reason: 'Third request after backoff');
      });
    },
  );
}
