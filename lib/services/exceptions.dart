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
      'JulesException: $message (Status: $statusCode)${context != null ? ' [Context: $context]' : ''}',
      error: message,
      stackTrace: StackTrace.current,
    );
    if (responseBody != null) {
      developer.log('Response body: $responseBody');
    }
  }

  @override
  String toString() {
    String msg = 'JulesException: $message';
    if (context != null) {
      msg += ' [Context: $context]';
    }
    if (responseBody != null) {
      msg += '\nResponse: $responseBody';
    }
    return msg;
  }
}

class InvalidTokenException extends JulesException {
  InvalidTokenException(String responseBody, {String? context})
      : super(
          'Invalid API token provided.',
          statusCode: 401,
          responseBody: responseBody,
          context: context,
        );
}

class PermissionDeniedException extends JulesException {
  PermissionDeniedException(String responseBody, {String? context})
      : super(
          'Permission denied.',
          statusCode: 403,
          responseBody: responseBody,
          context: context,
        );
}

class NotFoundException extends JulesException {
  NotFoundException(
    String responseBody, {
    String? resource,
    String? context,
  }) : super(
          resource != null
              ? 'Resource not found: $resource'
              : 'Resource not found.',
          statusCode: 404,
          responseBody: responseBody,
          context: context,
        );
}

class ApiException extends JulesException {
  ApiException(int statusCode, String responseBody, {String? context})
      : super(
          'API error occurred.',
          statusCode: statusCode,
          responseBody: responseBody,
          context: context,
        );
}

class ServiceUnavailableException extends JulesException {
  ServiceUnavailableException(String responseBody, {String? context})
      : super(
          'Service unavailable.',
          statusCode: 503,
          responseBody: responseBody,
          context: context,
        );
}

class RateLimitException extends JulesException {
  RateLimitException(String responseBody, {String? context})
      : super(
          'Rate limit exceeded.',
          statusCode: 429,
          responseBody: responseBody,
          context: context,
        );
}
