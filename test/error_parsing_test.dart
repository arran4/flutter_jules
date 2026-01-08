import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Parses RESOURCE_EXHAUSTED error correctly', () {
    const errorBody = '''
{
  "error": {
    "code": 429,
    "message": "Resource has been exhausted (e.g. check quota).",
    "status": "RESOURCE_EXHAUSTED"
  }
}
''';

    final body = jsonDecode(errorBody);
    bool isResourceExhausted = false;
    if (body is Map && body.containsKey('error')) {
      final error = body['error'];
      if (error is Map &&
          (error['code'] == 429 || error['status'] == 'RESOURCE_EXHAUSTED')) {
        isResourceExhausted = true;
      }
    }

    expect(isResourceExhausted, true);
  });

  test('Parses UNAVAILABLE error correctly', () {
    const errorBody = '''
{
  "error": {
    "code": 503,
    "message": "The service is currently unavailable.",
    "status": "UNAVAILABLE"
  }
}
''';

    final body = jsonDecode(errorBody);
    bool isUnavailable = false;
    if (body is Map && body.containsKey('error')) {
      final error = body['error'];
      if (error is Map &&
          (error['code'] == 503 || error['status'] == 'UNAVAILABLE')) {
        isUnavailable = true;
      }
    }

    expect(isUnavailable, true);
  });
}
