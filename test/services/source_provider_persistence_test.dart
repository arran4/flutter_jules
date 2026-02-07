import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/models/source.dart';
import 'package:flutter_jules/models/api_exchange.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/services/github_provider.dart';

// Mock JulesClient
class MockJulesClient extends Mock implements JulesClient {
  @override
  Future<ListSourcesResponse> listSources({
    int? pageSize,
    String? pageToken,
    void Function(ApiExchange)? onDebug,
  }) {
    return super.noSuchMethod(
      Invocation.method(#listSources, [], {
        #pageSize: pageSize,
        #pageToken: pageToken,
        #onDebug: onDebug,
      }),
      returnValue: Future.value(
        ListSourcesResponse(sources: [], nextPageToken: null),
      ),
    );
  }
}

class MockCacheService extends Mock implements CacheService {
  @override
  Future<List<CachedItem<Source>>> loadSources(String? token) {
    return super.noSuchMethod(
      Invocation.method(#loadSources, [token]),
      returnValue: Future.value(<CachedItem<Source>>[]),
    );
  }

  @override
  Future<void> saveSources(String? token, List<Source>? sources) {
    return super.noSuchMethod(
      Invocation.method(#saveSources, [token, sources]),
      returnValue: Future.value(),
    );
  }
}

class MockGithubProvider extends Mock implements GithubProvider {
  @override
  String? get apiKey => 'fake_token';

  @override
  GithubJob createRepoDetailsJob(String owner, String repo) {
    // Return a dummy job that completes immediately
    return GithubJob(id: 'mock', description: 'mock', action: () async => {})
      ..status = GithubJobStatus.completed
      ..result = <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>?> getRepoDetails(String owner, String repo) {
    return super.noSuchMethod(
      Invocation.method(#getRepoDetails, [owner, repo]),
      returnValue: Future.value(null),
    );
  }
}

void main() {
  group('SourceProvider Persistence and Options', () {
    late SourceProvider provider;
    late MockJulesClient mockClient;
    late MockCacheService mockCacheService;
    late MockGithubProvider mockGithubProvider;

    setUp(() {
      provider = SourceProvider();
      mockClient = MockJulesClient();
      mockCacheService = MockCacheService();

      // Stub loadSources
      when(
        mockCacheService.loadSources(any),
      ).thenAnswer((_) async => <CachedItem<Source>>[]);

      // Stub saveSources
      when(mockCacheService.saveSources(any, any)).thenAnswer((_) async {});

      mockGithubProvider = MockGithubProvider();
      provider.setCacheService(mockCacheService);
    });

    test('fetchSources parses and saves options', () async {
      final options = {
        'key': 'value',
        'nested': {'foo': 'bar'},
      };
      final sources = <Source>[
        Source(name: 'source1', id: 'id1', options: options),
      ];
      final response = ListSourcesResponse(
        sources: sources,
        nextPageToken: null,
      );

      when(
        mockClient.listSources(pageToken: anyNamed('pageToken')),
      ).thenAnswer((_) async => response);

      await provider.fetchSources(mockClient, authToken: 'auth_token');

      // Verify items have options
      expect(provider.items.length, 1);
      expect(provider.items[0].data.options, equals(options));

      // Verify saveSources was called with options
      final verification = verify(
        mockCacheService.saveSources('auth_token', captureAny),
      );
      verification.called(1);
      final savedSources = verification.captured.first as List<Source>;
      expect(savedSources.first.options, equals(options));
    });

    test('refreshSource updates branches and preserves options', () async {
      final options = {'key': 'preserved'};
      final oldRepo = GitHubRepo(
        owner: 'owner',
        repo: 'repo',
        isPrivate: false,
        branches: [],
      );
      final source = Source(
        name: 'source1',
        id: 'id1',
        githubRepo: oldRepo,
        options: options,
      );

      // Pre-populate provider with source
      // We can use fetchSources to populate or hack internal list via private API if available?
      // Since _items is private, we must use fetchSources to populate it.

      final response = ListSourcesResponse(
        sources: [source],
        nextPageToken: null,
      );
      when(
        mockClient.listSources(pageToken: anyNamed('pageToken')),
      ).thenAnswer((_) async => response);
      await provider.fetchSources(mockClient, authToken: 'auth_token');

      // Setup refresh
      final newBranches = [
        {'displayName': 'new-branch'},
      ];
      final details = {
        'repoName': 'repo',
        'branches': newBranches,
        'defaultBranch': 'main',
        'repoId': 123,
        'isPrivateGithub': false,
        'description': 'desc',
        'primaryLanguage': 'Dart',
        'license': 'MIT',
        'openIssuesCount': 0,
        'isFork': false,
        'forkParent': null,
      };

      when(
        mockGithubProvider.getRepoDetails('owner', 'repo'),
      ).thenAnswer((_) async => details);

      // Act
      await provider.refreshSource(
        source,
        authToken: 'auth_token',
        githubProvider: mockGithubProvider,
      );

      // Verify
      final updatedSource = provider.items[0].data;

      // Verify branches updated
      expect(updatedSource.githubRepo!.branches, isNotNull);
      expect(updatedSource.githubRepo!.branches!.length, 1);
      expect(updatedSource.githubRepo!.branches![0].displayName, 'new-branch');

      // Verify options preserved
      expect(updatedSource.options, equals(options));

      // Verify save called
      verify(
        mockCacheService.saveSources('auth_token', any),
      ).called(greaterThan(1)); // Initial fetch + refresh
    });
  });
}
