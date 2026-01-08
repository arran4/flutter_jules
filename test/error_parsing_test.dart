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
            (error['code'] == 429 ||
                error['status'] == 'RESOURCE_EXHAUSTED')) {
           isResourceExhausted = true;
        }
    }
    
    expect(isResourceExhausted, true);
  });
}
