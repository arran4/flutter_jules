import 'dart:convert';

enum ApiErrorType { rateLimit, dailyQuotaExceeded, serviceUnavailable, unknown }

class ApiErrorUtils {
  static ApiErrorType parseError(String? responseBody) {
    if (responseBody == null) return ApiErrorType.unknown;

    try {
      final body = jsonDecode(responseBody);
      if (body is Map && body.containsKey('error')) {
        final error = body['error'];
        if (error is Map) {
          final code = error['code'];
          final status = error['status'];

          if (code == 429 || status == 'RESOURCE_EXHAUSTED') {
            return ApiErrorType.rateLimit;
          }
          if (code == 400 && status == 'FAILED_PRECONDITION') {
            return ApiErrorType.dailyQuotaExceeded;
          }
          if (code == 503 || status == 'UNAVAILABLE') {
            return ApiErrorType.serviceUnavailable;
          }
        }
      }
    } catch (_) {
      // JSON parse error or unexpected structure
    }
    return ApiErrorType.unknown;
  }
}
