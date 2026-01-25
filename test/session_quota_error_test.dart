import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/utils/api_error_utils.dart';

void main() {
  group('ApiErrorUtils Parsing', () {
    test('Identifies standard 429 RESOURCE_EXHAUSTED error as rateLimit', () {
      final json = jsonEncode({
        "error": {
          "code": 429,
          "message": "Resource has been exhausted (e.g. check quota).",
          "status": "RESOURCE_EXHAUSTED",
        },
      });
      expect(ApiErrorUtils.parseError(json), ApiErrorType.rateLimit);
    });

    test(
      'Identifies new 400 FAILED_PRECONDITION error as dailyQuotaExceeded',
      () {
        final json = jsonEncode({
          "error": {
            "code": 400,
            "message": "Precondition check failed.",
            "status": "FAILED_PRECONDITION",
          },
        });
        expect(ApiErrorUtils.parseError(json), ApiErrorType.dailyQuotaExceeded);
      },
    );

    test('Identifies 503 UNAVAILABLE error as serviceUnavailable', () {
      final json = jsonEncode({
        "error": {
          "code": 503,
          "message": "Service Unavailable.",
          "status": "UNAVAILABLE",
        },
      });
      expect(ApiErrorUtils.parseError(json), ApiErrorType.serviceUnavailable);
    });

    test('Identifies unrelated 400 error as unknown', () {
      final json = jsonEncode({
        "error": {
          "code": 400,
          "message": "Bad Request.",
          "status": "INVALID_ARGUMENT",
        },
      });
      expect(ApiErrorUtils.parseError(json), ApiErrorType.unknown);
    });

    test('Returns unknown for null body', () {
      expect(ApiErrorUtils.parseError(null), ApiErrorType.unknown);
    });

    test('Returns unknown for invalid json', () {
      expect(ApiErrorUtils.parseError("{invalid json}"), ApiErrorType.unknown);
    });
  });
}
