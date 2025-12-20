class ApiExchange {
  final String method;
  final String url;
  final Map<String, String> requestHeaders;
  final String requestBody;
  final int statusCode;
  final Map<String, String> responseHeaders;
  final String responseBody;
  final DateTime timestamp;

  ApiExchange({
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.requestBody,
    required this.statusCode,
    required this.responseHeaders,
    required this.responseBody,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
