import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
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
  Future<void> _lastRequest = Future.value();

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

  Future<T> _enqueueRequest<T>(Future<T> Function() task) {
    final prevRequest = _lastRequest;
    final completer = Completer<T>();

    _lastRequest = completer.future.then((_) {}, onError: (_) {});

    _runTask(prevRequest, task, completer);

    return completer.future;
  }

  Future<void> _runTask<T>(
    Future<void> prevRequest,
    Future<T> Function() task,
    Completer<T> completer,
  ) async {
    await prevRequest;

    try {
      final result = await task();
      completer.complete(result);
    } catch (e, st) {
      completer.completeError(e, st);
    }
  }

  Future<http.Response> _performRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    void Function(ApiExchange)? onDebug,
  }) async {
    return _enqueueRequest(() async {
      final requestHeaders = headers ?? _headers;
      final requestBody = body != null ? jsonEncode(body) : '';

      int retryCount = 0;
      const maxRetries = 5;

      while (true) {
        http.Response response;
        try {
          if (method == 'GET') {
            response = await _client.get(url, headers: requestHeaders);
          } else if (method == 'POST') {
            response = await _client.post(
              url,
              headers: requestHeaders,
              body: requestBody,
            );
          } else {
            throw Exception('Unsupported method: $method');
          }
        } catch (e) {
          // In case of network error, we can't really log a response, but we rethrow
          rethrow;
        }

        if (onDebug != null) {
          onDebug(
            ApiExchange(
              method: method,
              url: url.toString(),
              requestHeaders: requestHeaders,
              requestBody: requestBody,
              statusCode: response.statusCode,
              responseHeaders: response.headers,
              responseBody: response.body,
            ),
          );
        }

        if ((response.statusCode == 429 || response.statusCode == 503) &&
            retryCount < maxRetries) {
          retryCount++;
          Duration waitDuration;
          final retryAfter = response.headers['retry-after'];

          if (retryAfter != null) {
            final seconds = int.tryParse(retryAfter);
            if (seconds != null) {
              waitDuration = Duration(seconds: seconds);
            } else {
              try {
                final date = HttpDate.parse(retryAfter);
                final now = DateTime.now();
                if (date.isAfter(now)) {
                  waitDuration = date.difference(now);
                } else {
                  waitDuration = Duration.zero;
                }
              } catch (_) {
                // Fallback to exponential if parsing fails
                waitDuration = Duration(seconds: 1 << (retryCount - 1));
              }
            }
          } else {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s
            waitDuration = Duration(seconds: 1 << (retryCount - 1));
          }

          developer.log(
            'Rate limited (Status: ${response.statusCode}). Retrying in ${waitDuration.inMilliseconds}ms. (Retry count: $retryCount)',
            name: 'JulesClient',
          );

          await Future.delayed(waitDuration);
          continue;
        }

        return response;
      }
    });
  }

  void _handleError(http.Response response) {
    if (response.statusCode == 401) {
      throw InvalidTokenException(response.body);
    } else if (response.statusCode == 403) {
      throw PermissionDeniedException(response.body);
    } else if (response.statusCode == 404) {
      throw NotFoundException(
        response.body,
        resource: response.request?.url.toString(),
      );
    } else if (response.statusCode == 429) {
      throw RateLimitException(response.body);
    } else if (response.statusCode == 503) {
      throw ServiceUnavailableException(response.body);
    } else {
      throw ApiException(response.statusCode, response.body);
    }
  }

  // --- Sessions ---

  Future<Session> createSession(
    Session session, {
    void Function(ApiExchange)? onDebug,
  }) async {
    final url = Uri.parse('$baseUrl/v1alpha/sessions');
    final response = await _performRequest(
      'POST',
      url,
      body: session.toJson(),
      onDebug: onDebug,
    );

    if (response.statusCode == 200) {
      return Session.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<Session> getSession(
    String name, {
    void Function(ApiExchange)? onDebug,
  }) async {
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
    bool Function(Session)? shouldStop,
  }) async {
    final queryParams = <String, String>{};
    if (pageSize != null) queryParams['pageSize'] = pageSize.toString();
    if (pageToken != null) queryParams['pageToken'] = pageToken;

    final uri = Uri.parse('$baseUrl/v1alpha/sessions');
    final params = Map<String, dynamic>.from(uri.queryParameters);
    params.addAll(queryParams);

    final url = uri.replace(queryParameters: params);
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final listResponse = ListSessionsResponse.fromJson(json);

      if (shouldStop != null) {
        final filteredSessions = <Session>[];
        for (final session in listResponse.sessions) {
          if (shouldStop(session)) {
            return ListSessionsResponse(
              sessions: filteredSessions,
              nextPageToken: null,
            );
          }
          filteredSessions.add(session);
        }
        // If we filtered nothing (didn't stop), we must ensure we return the items.
        // Since we iterated and added to filteredSessions, we should return that new list
        // attached to the original nextPageToken.
        return ListSessionsResponse(
          sessions: filteredSessions,
          nextPageToken: listResponse.nextPageToken,
        );
      }

      return listResponse;
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<void> approvePlan(
    String sessionName, {
    void Function(ApiExchange)? onDebug,
  }) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:approvePlan');
    final response = await _performRequest(
      'POST',
      url,
      body: {},
      onDebug: onDebug,
    );

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  Future<void> sendMessage(
    String sessionName,
    String message, {
    void Function(ApiExchange)? onDebug,
  }) async {
    final url = Uri.parse('$baseUrl/v1alpha/$sessionName:sendMessage');
    final response = await _performRequest(
      'POST',
      url,
      body: {'prompt': message},
      onDebug: onDebug,
    );

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  // --- Activities ---

  Future<Activity> getActivity(
    String name, {
    void Function(ApiExchange)? onDebug,
  }) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      return Activity.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<List<Activity>> listActivities(
    String sessionName, {
    void Function(ApiExchange)? onDebug,
    void Function(int loadedCount)? onProgress,
    bool Function(Activity)? shouldStop,
  }) async {
    List<Activity> allActivities = [];
    String? nextPageToken;

    do {
      final queryParams = <String, String>{};
      if (nextPageToken != null) {
        queryParams['pageToken'] = nextPageToken;
      }

      final uri = Uri.parse('$baseUrl/v1alpha/$sessionName/activities');
      final params = Map<String, dynamic>.from(uri.queryParameters);
      if (queryParams.isNotEmpty) {
        params.addAll(queryParams);
      }
      final url = uri.replace(queryParameters: params);

      final response = await _performRequest('GET', url, onDebug: onDebug);

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          final activities = getObjectArrayPropOrDefaultFunction(
            json,
            'activities',
            Activity.fromJson,
            () => <Activity>[],
          );

          if (shouldStop != null) {
            bool stop = false;
            for (final activity in activities) {
              if (shouldStop(activity)) {
                stop = true;
                break;
              }
              allActivities.add(activity);
            }
            if (stop) {
              nextPageToken = null;
            } else {
              nextPageToken = json['nextPageToken'] as String?;
            }
          } else {
            allActivities.addAll(activities);
            nextPageToken = json['nextPageToken'] as String?;
          }

          if (onProgress != null) {
            onProgress(allActivities.length);
          }
        } catch (e) {
          throw Exception(
            'Failed to parse activities response: $e\nResponse body: ${response.body}',
          );
        }
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } while (nextPageToken != null && nextPageToken.isNotEmpty);

    return allActivities;
  }

  // --- Sources ---

  Future<Source> getSource(
    String name, {
    void Function(ApiExchange)? onDebug,
  }) async {
    final url = Uri.parse('$baseUrl/v1alpha/$name');
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      return Source.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  Future<ListSourcesResponse> listSources({
    int? pageSize,
    String? pageToken,
    void Function(ApiExchange)? onDebug,
  }) async {
    final queryParams = <String, String>{};
    if (pageSize != null) queryParams['pageSize'] = pageSize.toString();
    if (pageToken != null) queryParams['pageToken'] = pageToken;

    final uri = Uri.parse('$baseUrl/v1alpha/sources');
    final params = Map<String, dynamic>.from(uri.queryParameters);
    params.addAll(queryParams);

    final url = uri.replace(queryParameters: params);
    final response = await _performRequest('GET', url, onDebug: onDebug);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return ListSourcesResponse.fromJson(json);
    } else {
      _handleError(response);
      throw Exception('Unreachable');
    }
  }

  void close() {
    _client.close();
  }
}
