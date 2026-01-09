import 'dart:developer' as developer;

class JulesException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  JulesException(this.message, {this.statusCode, this.responseBody}) {
    developer.log(
      'JulesException: $message (Status: $statusCode)',
      error: message,
      stackTrace: StackTrace.current,
    );
    if (responseBody != null) {
      developer.log('Response body: $responseBody');
    }
  }

  @override
  String toString() {
    if (responseBody != null) {
      return 'JulesException: $message\nResponse: $responseBody';
    }
    return 'JulesException: $message';
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
    : super('Permission denied.', statusCode: 403, responseBody: responseBody);
}

class NotFoundException extends JulesException {
  NotFoundException(String responseBody)
    : super('Resource not found.', statusCode: 404, responseBody: responseBody);
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
