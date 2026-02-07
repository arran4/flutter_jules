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

  @override
  Future<Source> getSource(
    String? name, {
    void Function(ApiExchange)? onDebug,
  }) {
    return super.noSuchMethod(
      Invocation.method(#getSource, [name], {#onDebug: onDebug}),
      returnValue: Future.value(Source(name: 'mock', id: 'mock')),
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
  void enqueue(GithubJob job) {
    // Execute immediately for testing purposes
    job.action().then((result) {
      job.result = result;
      job.status = GithubJobStatus.completed;
      job.completer.complete();
    }).catchError((e) {
      job.status = GithubJobStatus.failed;
      job.error = e.toString();
      job.completer.completeError(e);
    });
  }

  @override
  GithubJob createRepoDetailsJob(String owner, String repo) {
    return super.noSuchMethod(
      Invocation.method(#createRepoDetailsJob, [owner, repo]),
      returnValue: GithubJob(
        id: 'mock',
        description: 'mock',
        action: () async => {},
      ),
    );
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
  group('SourceProvider Branch Combining', () {
    late SourceProvider provider;
    late MockJulesClient mockClient;
    late MockCacheService mockCacheService;
    late MockGithubProvider mockGithubProvider;

    setUp(() {
      provider = SourceProvider();
      mockClient = MockJulesClient();
      mockCacheService = MockCacheService();
      mockGithubProvider = MockGithubProvider();

      when(mockCacheService.loadSources(any))
          .thenAnswer((_) async => <CachedItem<Source>>[]);
      when(mockCacheService.saveSources(any, any)).thenAnswer((_) async {});

      provider.setCacheService(mockCacheService);
    });

    test('refreshSource combines branches', () async {
      // Setup initial source with "jules-branch"
      final julesBranch = GitHubBranch(displayName: 'jules-branch');
      final oldRepo = GitHubRepo(
        owner: 'owner',
        repo: 'repo',
        isPrivate: false,
        branches: [julesBranch],
      );
      final source = Source(
        name: 'source1',
        id: 'id1',
        githubRepo: oldRepo,
      );

      final response = ListSourcesResponse(
        sources: [source],
        nextPageToken: null,
      );
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenAnswer((_) async => response);
      await provider.fetchSources(mockClient, authToken: 'auth_token');

      // Setup GitHub provider to return "github-branch"
      final githubDetails = {
        'repoName': 'repo',
        'branches': [
          {'displayName': 'github-branch'}
        ],
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

      when(mockGithubProvider.getRepoDetails('owner', 'repo'))
          .thenAnswer((_) async => githubDetails);

      // Act
      // We need to mock getSource to return the source (or a version of it)
      when(mockClient.getSource(source.name))
          .thenAnswer((_) async => source); // Return original source from Jules API

      await provider.refreshSource(
        mockClient,
        source,
        authToken: 'auth_token',
        githubProvider: mockGithubProvider,
      );

      // Verify
      final updatedSource = provider.items[0].data;
      final branchNames =
          updatedSource.githubRepo!.branches!.map((b) => b.displayName).toSet();

      expect(branchNames, containsAll(['jules-branch', 'github-branch']));
    });

    test('queueAllSourcesGithubRefresh combines branches', () async {
      // Setup initial source with "jules-branch"
      final julesBranch = GitHubBranch(displayName: 'jules-branch');
      final oldRepo = GitHubRepo(
        owner: 'owner',
        repo: 'repo',
        isPrivate: false,
        branches: [julesBranch],
      );
      final source = Source(
        name: 'source1',
        id: 'id1',
        githubRepo: oldRepo,
      );

      final response = ListSourcesResponse(
        sources: [source],
        nextPageToken: null,
      );
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenAnswer((_) async => response);
      await provider.fetchSources(mockClient, authToken: 'auth_token');

      // Setup GitHub provider to return "github-branch"
      final githubDetails = {
        'repoName': 'repo',
        'branches': [
          {'displayName': 'github-branch'}
        ],
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

      // Mock createRepoDetailsJob to return a job that resolves with githubDetails
      final job = GithubJob(
        id: 'job1',
        description: 'desc',
        action: () async => githubDetails,
      );
      // We need to simulate the job running.
      // In our mock enqueue, we execute it.

      when(mockGithubProvider.createRepoDetailsJob('owner', 'repo'))
          .thenReturn(job);

      // Act
      provider.queueAllSourcesGithubRefresh(
        githubProvider: mockGithubProvider,
        authToken: 'auth_token',
      );

      // Wait for async operations (enqueue runs action which updates source)
      await Future.delayed(Duration.zero);
      // We need to wait for the job's future to complete and then for the provider to process it.
      await job.completer.future;
      // queueAllSourcesGithubRefresh attaches a .then() to the completer.future.
      // We need to wait a tick for that .then() to execute.
      await Future.delayed(Duration.zero);

      // Verify
      final updatedSource = provider.items[0].data;
      final branchNames =
          updatedSource.githubRepo!.branches!.map((b) => b.displayName).toSet();

      expect(branchNames, containsAll(['jules-branch', 'github-branch']));
    });
  });
}
