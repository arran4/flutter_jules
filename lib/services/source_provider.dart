import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import 'github_provider.dart';
import 'jules_client.dart';
import 'cache_service.dart';
import 'session_provider.dart';

class SourceProvider extends ChangeNotifier {
  List<CachedItem<Source>> _items = [];
  bool _isLoading = false;
  String? _error;
  CacheService? _cacheService;
  DateTime? _lastFetchTime;
  final Set<String> _refreshingSources = {};

  List<CachedItem<Source>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;

  void setCacheService(CacheService service) {
    _cacheService = service;
  }

  Future<void> fetchSources(
    JulesClient client, {
    bool force = false,
    String? authToken,
    GithubProvider? githubProvider,
    void Function(int total)? onProgress,
    SessionProvider? sessionProvider,
  }) async {
    // 1. Initial Load from Cache
    if (_cacheService != null && authToken != null) {
      if (!force) {
        _items = await _cacheService!.loadSources(authToken);
        notifyListeners();
        if (_items.isNotEmpty) {
          // If we have items and not forcing, we can stop.
          return;
        }
      }
    }

    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<Source> allSources = [];
      String? pageToken;
      int page = 0;
      do {
        page++;
        if (onProgress != null) {
          onProgress(page);
        }
        final response = await client.listSources(pageToken: pageToken);
        allSources.addAll(response.sources);
        pageToken = response.nextPageToken;
        if (onProgress != null) {
          onProgress(allSources.length);
        }
      } while (pageToken != null && pageToken.isNotEmpty);

      if (_cacheService != null && authToken != null) {
        await _cacheService!.saveSources(authToken, allSources);
        _items = await _cacheService!.loadSources(authToken);
      } else {
        final now = DateTime.now();
        _items = allSources
            .map(
              (s) => CachedItem(
                s,
                CacheMetadata(firstSeen: now, lastRetrieved: now),
              ),
            )
            .toList();
      }

      // After loading sources, queue the github refresh
      if (githubProvider != null) {
        queueAllSourcesGithubRefresh(
          githubProvider: githubProvider,
          authToken: authToken,
        );
      }

      _lastFetchTime = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void queueAllSourcesGithubRefresh({
    required GithubProvider githubProvider,
    String? authToken,
  }) {
    if (githubProvider.apiKey == null) {
      return;
    }

    for (final item in _items) {
      final source = item.data;
      if (source.githubRepo != null) {
        final job = githubProvider.createRepoDetailsJob(
          source.githubRepo!.owner,
          source.githubRepo!.repo,
        );

        job.completer.future.then((_) {
          if (job.status == GithubJobStatus.completed) {
            final details = job.result as Map<String, dynamic>?;
            if (details != null) {
              _updateSourceWithGithubDetails(
                source.name,
                details,
                authToken,
              );
            }
          }
        }).catchError((err) {
          // Silently ignore, errors are handled in the provider
        });

        githubProvider.enqueue(job);
      }
    }
  }

  Future<void> _updateSourceWithGithubDetails(
    String sourceName,
    Map<String, dynamic> details,
    String? authToken,
  ) async {
    final index = _items.indexWhere((item) => item.data.name == sourceName);
    if (index == -1) return;

    final oldItem = _items[index];
    final oldSource = oldItem.data;
    if (oldSource.githubRepo == null) return;

    final enrichedRepo = GitHubRepo(
      owner: oldSource.githubRepo!.owner,
      repo: oldSource.githubRepo!.repo,
      isPrivate: oldSource.githubRepo!.isPrivate,
      defaultBranch: oldSource.githubRepo!.defaultBranch ??
          (details['defaultBranch'] != null
              ? GitHubBranch(displayName: details['defaultBranch'])
              : null),
      branches: (oldSource.githubRepo!.branches?.isNotEmpty ?? false)
          ? oldSource.githubRepo!.branches
          : (details['branches'] != null &&
                  (details['branches'] as List).isNotEmpty
              ? (details['branches'] as List)
                  .map((b) => GitHubBranch(displayName: b['displayName']))
                  .toList()
              : oldSource.githubRepo!.branches),
      repoName: details['repoName'],
      repoId: details['repoId'],
      isPrivateGithub: details['isPrivateGithub'],
      description: details['description'],
      primaryLanguage: details['primaryLanguage'],
      license: details['license'],
      openIssuesCount: details['openIssuesCount'],
      isFork: details['isFork'],
      forkParent: details['forkParent'],
    );

    final updatedSource = Source(
      name: oldSource.name,
      id: oldSource.id,
      githubRepo: enrichedRepo,
      isArchived: oldSource.isArchived,
      isReadOnly: oldSource.isReadOnly,
    );

    final newItem = CachedItem(
      updatedSource,
      oldItem.metadata.copyWith(lastUpdated: DateTime.now()),
    );

    _items[index] = newItem;

    if (_cacheService != null && authToken != null) {
      final allSources = _items.map((item) => item.data).toList();
      await _cacheService!.saveSources(authToken, allSources);
    }

    notifyListeners();
  }

  // Helper to ensure a specific source is in the cache/list, triggering refresh if missing.
  Future<void> ensureSourceAvailable(
    JulesClient client,
    String sourceName, {
    String? authToken,
  }) async {
    // Check if we already have it
    final exists = _items.any(
      (item) => item.data.name == sourceName || item.data.id == sourceName,
    );
    if (!exists) {
      // Trigger non-forced refresh (actually forced to ensure we get new data,
      // but 'force' arg in our fetchSources logic currently acts as "always fetch").
      // We will call fetchSources with force=true to get latest list which hopefully contains the new source.
      await fetchSources(client, force: true, authToken: authToken);
    }
  }

  Future<void> refreshSource(
    Source sourceToRefresh, {
    String? authToken,
    GithubProvider? githubProvider,
  }) async {
    if (_refreshingSources.contains(sourceToRefresh.name)) {
      return;
    }

    if (githubProvider == null ||
        githubProvider.apiKey == null ||
        sourceToRefresh.githubRepo == null) {
      return;
    }

    final index = _items.indexWhere(
      (item) => item.data.name == sourceToRefresh.name,
    );
    if (index == -1) {
      return; // Source not found in the list
    }

    try {
      _refreshingSources.add(sourceToRefresh.name);
      final details = await githubProvider.getRepoDetails(
        sourceToRefresh.githubRepo!.owner,
        sourceToRefresh.githubRepo!.repo,
      );

      if (details != null) {
        final enrichedRepo = GitHubRepo(
          owner: sourceToRefresh.githubRepo!.owner,
          repo: sourceToRefresh.githubRepo!.repo,
          isPrivate: sourceToRefresh.githubRepo!.isPrivate,
          defaultBranch: sourceToRefresh.githubRepo!.defaultBranch,
          branches: sourceToRefresh.githubRepo!.branches,
          repoName: details['repoName'],
          repoId: details['repoId'],
          isPrivateGithub: details['isPrivateGithub'],
          description: details['description'],
          primaryLanguage: details['primaryLanguage'],
          license: details['license'],
          openIssuesCount: details['openIssuesCount'],
          isFork: details['isFork'],
          forkParent: details['forkParent'],
        );

        final updatedSource = Source(
          name: sourceToRefresh.name,
          id: sourceToRefresh.id,
          githubRepo: enrichedRepo,
          isArchived: sourceToRefresh.isArchived,
          isReadOnly: sourceToRefresh.isReadOnly,
        );

        final oldItem = _items[index];
        final newItem = CachedItem(
          updatedSource,
          oldItem.metadata.copyWith(
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now(),
          ),
        );

        _items[index] = newItem;

        if (_cacheService != null && authToken != null) {
          final allSources = _items.map((item) => item.data).toList();
          await _cacheService!.saveSources(authToken, allSources);
        }

        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to refresh source ${sourceToRefresh.name}: $e';
      notifyListeners();
      rethrow;
    } finally {
      _refreshingSources.remove(sourceToRefresh.name);
    }
  }
}
