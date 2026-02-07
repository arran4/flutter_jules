import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/services/auth_service.dart';
import 'dart:convert';
import 'dart:io';

// Fake implementations

class FakeAuthService extends Fake implements AuthService {
  String? _token;
  @override
  Future<String?> getGithubToken() async => _token;
  @override
  Future<void> saveGithubToken(String token) async => _token = token;
}

class FakeCacheService extends Fake implements CacheService {
  @override
  Future<File> getGithubFailuresLogFile(String key) async {
    // Return a dummy file path (it won't be written to because we mock failure logging usually)
    // But if _logFailure is called, it tries to write.
    // We can just throw, and GithubProvider catches and prints.
    throw Exception("Not implemented");
  }
}

void main() {
  group('GithubProvider', () {
    late GithubProvider provider;
    late SettingsProvider settingsProvider;
    late FakeAuthService authService;
    late MockClient mockClient;
    late FakeCacheService cacheService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsProvider = SettingsProvider();
      await settingsProvider.init();

      authService = FakeAuthService();
      cacheService = FakeCacheService();

      // Default dummy client
      mockClient = MockClient((request) async {
        return http.Response('{}', 404);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
    });

    test('getPrStatus sends Authorization header with token', () async {
      authService._token = 'test_token';

      mockClient = MockClient((request) async {
        if (request.url.path.contains('/pulls/123')) {
          if (request.headers['Authorization'] == 'token test_token') {
            return http.Response(
              jsonEncode({
                'state': 'open',
                '_links': {
                  'html': {'href': 'http://url'},
                },
              }),
              200,
            );
          } else {
            return http.Response('Unauthorized', 401);
          }
        }
        return http.Response('Not Found', 404);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
      await provider.setApiKey('test_token'); // Ensure token is loaded

      final result = await provider.getPrStatus('owner', 'repo', '123');
      expect(result, isNotNull);
      expect(result!.state, 'open');
    });

    test('getPrStatus returns null when token is missing', () async {
      authService._token = null; // No token

      // Capture requests
      bool requestMade = false;
      mockClient = MockClient((request) async {
        requestMade = true;
        return http.Response('{}', 200);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
      // Token is null initially.

      final result = await provider.getPrStatus('owner', 'repo', '123');
      expect(result, isNull);
      expect(requestMade, isFalse);
    });

    test('getDiff sends Authorization header', () async {
      authService._token = 'diff_token';

      bool headerCorrect = false;
      mockClient = MockClient((request) async {
        if (request.headers['Authorization'] == 'token diff_token' &&
            request.headers['Accept'] == 'application/vnd.github.v3.diff') {
          headerCorrect = true;
          return http.Response('diff content', 200);
        }
        return http.Response('Error', 400);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
      await provider.setApiKey('diff_token');

      final result = await provider.getDiff('owner', 'repo', '123');
      expect(result, 'diff content');
      expect(headerCorrect, isTrue);
    });

    test('getPatch sends Authorization header', () async {
      authService._token = 'patch_token';

      bool headerCorrect = false;
      mockClient = MockClient((request) async {
        if (request.headers['Authorization'] == 'token patch_token' &&
            request.headers['Accept'] == 'application/vnd.github.v3.patch') {
          headerCorrect = true;
          return http.Response('patch content', 200);
        }
        return http.Response('Error', 400);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
      await provider.setApiKey('patch_token');

      final result = await provider.getPatch('owner', 'repo', '123');
      expect(result, 'patch content');
      expect(headerCorrect, isTrue);
    });

    test('createRepoDetailsJob action sends Authorization header', () async {
      authService._token = 'repo_token';

      bool headerCorrect = false;
      mockClient = MockClient((request) async {
        if (request.headers['Authorization'] == 'token repo_token') {
          headerCorrect = true;
          return http.Response(
            jsonEncode({
              'name': 'repo',
              'id': 1,
              'private': false,
              'open_issues_count': 0,
              'fork': false,
              'default_branch': 'main',
              'description': 'desc',
              'language': 'Dart',
            }),
            200,
          );
        }
        // Handle branches call
        if (request.url.path.endsWith('/branches')) {
          return http.Response('[]', 200);
        }
        return http.Response('Error', 400);
      });

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );
      await provider.setApiKey('repo_token');

      final job = provider.createRepoDetailsJob('owner', 'repo');
      await job.action();

      expect(headerCorrect, isTrue);
    });

    test('createRepoDetailsJob throws if token is missing', () async {
      authService._token = null;

      provider = GithubProvider(
        settingsProvider,
        cacheService,
        authService: authService,
        client: mockClient,
      );

      final job = provider.createRepoDetailsJob('owner', 'repo');

      expect(() => job.action(), throwsException);
    });
  });
}
