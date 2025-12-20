import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class JulesClient {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  JulesClient({
    this.baseUrl = 'https://jules.googleapis.com',
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  // --- Sessions ---

  Future<Session> createSession(Session session) async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(session.toJson()),
    );

    if (response.statusCode == 200) {
      try {
        return Session.fromJson(jsonDecode(response.body));
      } catch (e) {
        print('Failed to parse createSession response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse createSession response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to create session: ${response.body}');
    }
  }

  Future<Session> getSession(String name) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      try {
        return Session.fromJson(jsonDecode(response.body));
      } catch (e) {
        print('Failed to parse getSession response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse getSession response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to get session: ${response.body}');
    }
  }

  Future<List<Session>> listSessions() async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        if (json['sessions'] != null) {
          return (json['sessions'] as List)
              .map((e) => Session.fromJson(e))
              .toList();
        } else {
          return [];
        }
      } catch (e) {
        print('Failed to parse listSessions response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse listSessions response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to list sessions: ${response.body}');
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
      throw Exception('Failed to approve plan: ${response.body}');
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
      throw Exception('Failed to send message: ${response.body}');
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
      try {
        return Activity.fromJson(jsonDecode(response.body));
      } catch (e) {
        print('Failed to parse getActivity response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse getActivity response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to get activity: ${response.body}');
    }
  }

  Future<List<Activity>> listActivities(String sessionName) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName/activities');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        if (json['activities'] != null) {
          return (json['activities'] as List)
              .map((e) => Activity.fromJson(e))
              .toList();
        } else {
          return [];
        }
      } catch (e) {
        print('Failed to parse listActivities response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse listActivities response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to list activities: ${response.body}');
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
      try {
        return Source.fromJson(jsonDecode(response.body));
      } catch (e) {
        print('Failed to parse getSource response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse getSource response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to get source: ${response.body}');
    }
  }

  Future<List<Source>> listSources() async {
    final url = Uri.parse('$baseUrl/v1alpha/sources');
    final response = await _client.get(
      url,
      headers: _headers,
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        if (json['sources'] != null) {
          return (json['sources'] as List)
              .map((e) => Source.fromJson(e))
              .toList();
        } else {
          return [];
        }
      } catch (e) {
        print('Failed to parse listSources response: $e');
        print('Body: ${response.body}');
        throw Exception(
            'Failed to parse listSources response: $e\nBody: ${response.body}');
      }
    } else {
      throw Exception('Failed to list sources: ${response.body}');
    }
  }

  void close() {
    _client.close();
  }
}
