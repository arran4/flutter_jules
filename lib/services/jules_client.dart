import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartobjectutils/dartobjectutils.dart';
import '../models.dart';
import '../models/api_exchange.dart';
import 'exceptions.dart';

class JulesClient {
  final String baseUrl;
  final String? apiKey;
  final String? accessToken;
  final http.Client _client;

  JulesClient({
    this.baseUrl = 'https://jules.googleapis.com',
    this.apiKey,
    this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        if (apiKey != null) 'X-Goog-Api-Key': apiKey!,
      };

  Future<http.Response> _performRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    void Function(ApiExchange)? onDebug,
  }) async {
    final requestHeaders = headers ?? _headers;
    final requestBody = body != null ? jsonEncode(body) : '';

    http.Response response;
    try {
      if (method == 'GET') {
        response = await _client.get(url, headers: requestHeaders);
      } else if (method == 'POST') {
        response = await _client.post(url, headers: requestHeaders, body: requestBody);
      } else {
        throw Exception('Unsupported method: $method');
      }
    } catch (e) {
      // In case of network error, we can't really log a response, but we rethrow
      rethrow;
    }

    if (onDebug != null) {
      onDebug(ApiExchange(
        method: method,
        url: url.toString(),
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: response.body,
      ));
    }

    return response;
  }

  void _handleError(http.Response response) {
    if (response.statusCode == 401) {
      throw InvalidTokenException(response.body);
    } else if (response.statusCode == 403) {
      throw PermissionDeniedException(response.body);
    } else if (response.statusCode == 404) {
      throw NotFoundException(response.body);
    } else {
      throw ApiException(response.statusCode, response.body);
    }
  }

  // --- Sessions ---

  Future<Session> createSession(Session session, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _performRequest('POST', url, body: session.toJson(), onDebug: onDebug);

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<Session> getSession(String name, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<ListSessionsResponse> listSessions({
    int? pageSize,
    String? pageToken,
    void Function(ApiExchange)? onDebug,
  }) async {
    final queryParams = <String, String>{};
    if (pageSize != null) queryParams['pageSize'] = pageSize.toString();
    if (pageToken != null) queryParams['pageToken'] = pageToken;

    final url = Uri.parse('$baseUrl/v1alpha/sessions').replace(queryParameters: queryParams);
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ListSessionsResponse.fromJson(json);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<void> approvePlan(String sessionName, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:approvePlan');
    final response = await _performRequest('POST', url, body: {}, onDebug: onDebug);

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  Future<void> sendMessage(String sessionName, String message, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:sendMessage');
    final response = await _performRequest('POST', url, body: {'message': message}, onDebug: onDebug);

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  // --- Activities ---

  Future<Activity> getActivity(String name, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      return Activity.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Activity>> listActivities(String sessionName, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName/activities');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return getObjectArrayPropOrDefaultFunction(json, 'activities', Activity.fromJson, () => <Activity>[]);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  // --- Sources ---

  Future<Source> getSource(String name, {void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      return Source.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Source>> listSources({void Function(ApiExchange)? onDebug}) async {
    final url = Uri.parse('$baseUrl/v1alpha/sources');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return getObjectArrayPropOrDefaultFunction(json, 'sources', Source.fromJson, () => <Source>[]);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  void close() {
    _client.close();
  }
}
