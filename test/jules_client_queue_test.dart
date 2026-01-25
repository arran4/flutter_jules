import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_jules/services/jules_client.dart';

class MockHttpClient extends http.BaseClient {
  final List<String> logs;

  MockHttpClient(this.logs);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final id = request.url.pathSegments.last;
    logs.add('Start $id');
    // Use a small delay to simulate network latency
    await Future.delayed(const Duration(milliseconds: 50));
    logs.add('End $id');

    return http.StreamedResponse(
      Stream.fromIterable([
        '{"name": "test_name", "id": "test_id", "prompt": "test_prompt"}'
            .codeUnits,
      ]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('JulesClient requests are serialized', () async {
    final logs = <String>[];
    final mockHttp = MockHttpClient(logs);
    final client = JulesClient(client: mockHttp, baseUrl: 'http://example.com');

    // Fire two requests "concurrently"
    // We intentionally don't await the first one before starting the second one
    final f1 = client.getSession('req1');
    final f2 = client.getSession('req2');

    await Future.wait([f1, f2]);

    // Expectation for serialized requests:
    // Start req1, End req1, Start req2, End req2
    // If they are concurrent, we'd likely see Start req1, Start req2...

    expect(logs, ['Start req1', 'End req1', 'Start req2', 'End req2']);
  });
}
