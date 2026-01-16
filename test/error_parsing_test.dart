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

  test('Parses API Key Not Supported (401) error correctly', () {
    const errorBody = '''
{
  "error": {
    "code": 401,
    "message": "API keys are not supported by this API. Expected OAuth2 access token or other authentication credentials that assert a principal. See https://cloud.google.com/docs/authentication",
    "status": "UNAUTHENTICATED",
    "details": [
      {
        "@type": "type.googleapis.com/google.rpc.ErrorInfo",
        "reason": "CREDENTIALS_MISSING",
        "domain": "googleapis.com",
        "metadata": {
          "method": "google.labs.jules.v1alpha.JulesService.CreateSession",
          "service": "jules.googleapis.com"
        }
      }
    ]
  }
}
''';

    final body = jsonDecode(errorBody);
    bool isApiKeyError = false;
    if (body is Map && body.containsKey('error')) {
      final error = body['error'];
      if (error is Map) {
         if (error['code'] == 401 || error['status'] == 'UNAUTHENTICATED') {
             // Check for specific message or reason if needed, but 401 is usually enough for this flow
             isApiKeyError = true;
         }
      }
    }

    expect(isApiKeyError, true);
  });
}
