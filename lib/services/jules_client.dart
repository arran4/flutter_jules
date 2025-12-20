import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartobjectutils/dartobjectutils.dart';
import '../models.dart';
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

  Future<Session> createSession(Session session) async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(session.toJson()),
    );

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<Session> getSession(String name) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Session>> listSessions() async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return getObjectArrayPropOrDefaultFunction(json, 'sessions', Session.fromJson, () => <Session>[]);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<void> approvePlan(String sessionName) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:approvePlan');
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  Future<void> sendMessage(String sessionName, String message) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:sendMessage');
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  // --- Activities ---

  Future<Activity> getActivity(String name) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return Activity.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Activity>> listActivities(String sessionName) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName/activities');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return getObjectArrayPropOrDefaultFunction(json, 'activities', Activity.fromJson, () => <Activity>[]);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  // --- Sources ---

  Future<Source> getSource(String name) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return Source.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Source>> listSources() async {
    final url = Uri.parse('$baseUrl/v1alpha/sources');
    final response = await _client.get(
      url,
      headers: _headers,
    );

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
