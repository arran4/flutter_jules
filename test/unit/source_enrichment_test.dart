import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/models.dart';

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

class MockGithubProvider extends Mock implements GithubProvider {
  @override
  String? get apiKey => 'test-token';

  @override
  GithubJob createRepoDetailsJob(String owner, String repo) {
    // Return a job that returns our enriched data
    final job = GithubJob(
      id: 'mock_job_${owner}_$repo',
      description: 'Mock Job',
      action: () async {
        return {
          'repoName': repo,
          'repoId': 123,
          'isPrivateGithub': false,
          'description': 'Test Description',
          'primaryLanguage': 'Dart',
          'license': 'MIT',
          'openIssuesCount': 0,
          'isFork': false,
          'forkParent': null,
          'html_url': 'https://github.com/$owner/$repo',
          'defaultBranch': 'master', // New field
          'branches': [
            {'displayName': 'master'},
            {'displayName': 'feature-branch'},
          ], // New field
        };
      },
    );
    return job;
  }

  @override
  void enqueue(GithubJob job) {
    // Execute immediately
    job.status = GithubJobStatus.running;
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
}

void main() {
  group('Source Enrichment', () {
    late SourceProvider provider;
    late MockJulesClient mockClient;
    late MockGithubProvider mockGithubProvider;

    setUp(() {
      provider = SourceProvider();
      mockClient = MockJulesClient();
      mockGithubProvider = MockGithubProvider();
    });

    test('fetches and enriches source with branch details', () async {
      // 1. Setup initial source with missing branch info
      final initialRepo = GitHubRepo(
        owner: 'testowner',
        repo: 'testrepo',
        isPrivate: false,
        // Default branch and branches are null initially
      );
      final initialSource = Source(
        name: 'sources/test',
        id: 'test_id',
        githubRepo: initialRepo,
      );

      when(mockClient.listSources(pageToken: anyNamed('pageToken'))).thenAnswer(
        (_) async =>
            ListSourcesResponse(sources: [initialSource], nextPageToken: null),
      );

      // 2. Call fetchSources with githubProvider
      await provider.fetchSources(
        mockClient,
        force: true,
        authToken: 'auth-token',
        githubProvider: mockGithubProvider,
      );

      // 3. Wait for async enrichment (SourceProvider queues it but doesn't await it in fetchSources)
      // Since our mock enqueue executes immediately, we just need to wait a tick?
      // SourceProvider uses job.completer.future.then(...)
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero); // Give event loop time

      // 4. Assert
      final source = provider.items.first.data;
      expect(source.githubRepo, isNotNull);
      expect(source.githubRepo!.defaultBranch, isNotNull);
      expect(source.githubRepo!.defaultBranch!.displayName, 'master');
      expect(source.githubRepo!.branches, isNotNull);
      expect(source.githubRepo!.branches!.length, 2);
      expect(source.githubRepo!.branches![0].displayName, 'master');
      expect(source.githubRepo!.branches![1].displayName, 'feature-branch');
    });
  });
}
