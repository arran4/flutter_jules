import 'dart:developer' as developer;

class JulesException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? context;

  JulesException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.context,
  }) {
    developer.log(
      'JulesException: $message (Status: $statusCode)',
      error: message,
      stackTrace: StackTrace.current,
    );
    if (context != null) {
      developer.log('Context: $context');
    }
    if (responseBody != null) {
      developer.log('Response body: $responseBody');
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('JulesException: $message');
    if (context != null) {
      buffer.write('\nContext: $context');
    }
    if (responseBody != null) {
      buffer.write('\nResponse: $responseBody');
    }
    return buffer.toString();
  }
}

class InvalidTokenException extends JulesException {
  InvalidTokenException(String responseBody)
      : super(
          'Invalid API token provided.',
          statusCode: 401,
          responseBody: responseBody,
        );
}

class PermissionDeniedException extends JulesException {
  PermissionDeniedException(String responseBody)
      : super('Permission denied.',
            statusCode: 403, responseBody: responseBody);
}

class NotFoundException extends JulesException {
  NotFoundException(String responseBody, {String? resource})
      : super(
          resource != null
              ? 'Resource not found: $resource'
              : 'Resource not found.',
          statusCode: 404,
          responseBody: responseBody,
        );
}

class ApiException extends JulesException {
  ApiException(int statusCode, String responseBody)
      : super(
          'API error occurred.',
          statusCode: statusCode,
          responseBody: responseBody,
        );
}

class ServiceUnavailableException extends JulesException {
  ServiceUnavailableException(String responseBody)
      : super(
          'Service unavailable.',
          statusCode: 503,
          responseBody: responseBody,
        );
}

class RateLimitException extends JulesException {
  RateLimitException(String responseBody)
      : super(
          'Rate limit exceeded.',
          statusCode: 429,
          responseBody: responseBody,
        );
}
