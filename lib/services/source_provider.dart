import 'package:flutter/material.dart';
import '../models.dart';

import 'jules_client.dart';
import 'cache_service.dart';

class SourceProvider extends ChangeNotifier {
  List<CachedItem<Source>> _items = [];
  bool _isLoading = false;
  String? _error;
  CacheService? _cacheService;
  DateTime? _lastFetchTime;

  List<CachedItem<Source>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;

  void setCacheService(CacheService service) {
    _cacheService = service;
  }

  Future<void> refreshSources(
    JulesClient client, {
    bool force = false,
    String? authToken,
    GithubProvider? githubProvider,
  }) async {
    if (_isLoading) return;

    if (_cacheService != null && authToken != null && !force) {
      _items = await _cacheService!.loadSources(authToken);
      if (_items.isNotEmpty) {
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<Source> allSources = [];
      String? pageToken;

      do {
        final response = await client.listSources(pageToken: pageToken);
        allSources.addAll(response.sources);
        pageToken = response.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);

      if (githubProvider != null) {
        List<Source> enrichedSources = [];
        for (var source in allSources) {
          if (source.githubRepo != null) {
            final details = await githubProvider.getRepoDetails(
              source.githubRepo!.owner,
              source.githubRepo!.repo,
            );
            if (details != null) {
              final newGitHubRepo = GitHubRepo(
                owner: source.githubRepo!.owner,
                repo: source.githubRepo!.repo,
                isPrivate: source.githubRepo!.isPrivate,
                defaultBranch: source.githubRepo!.defaultBranch,
                branches: source.githubRepo!.branches,
                repoName: details['name'],
                repoId: details['id'],
                isPrivateGh: details['private'],
                description: details['description'],
                primaryLanguage: details['language'],
                license: details['license']?['name'],
                openIssuesCount: details['open_issues_count'],
                isFork: details['fork'],
              );
              final newSource = Source(
                name: source.name,
                id: source.id,
                githubRepo: newGitHubRepo,
              );
              enrichedSources.add(newSource);
            } else {
              enrichedSources.add(source);
            }
          } else {
            enrichedSources.add(source);
          }
        }
        allSources = enrichedSources;
      }

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
      _lastFetchTime = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSources(
    JulesClient client, {
    bool force = false,
    String? authToken,
    GithubProvider? githubProvider,
  }) async {
    await refreshSources(
      client,
      force: force,
      authToken: authToken,
      githubProvider: githubProvider,
    );
  }

  // Helper to ensure a specific source is in the cache/list, triggering refresh if missing.
  Future<void> ensureSourceAvailable(
    JulesClient client,
    String sourceName, {
    String? authToken,
    GithubProvider? githubProvider,
  }) async {
    // Check if we already have it
    final exists = _items.any(
      (item) => item.data.name == sourceName || item.data.id == sourceName,
    );
    if (!exists) {
      // Trigger non-forced refresh (actually forced to ensure we get new data,
      // but 'force' arg in our fetchSources logic currently acts as "always fetch").
      // We will call fetchSources with force=true to get latest list which hopefully contains the new source.
      await fetchSources(
        client,
        force: true,
        authToken: authToken,
        githubProvider: githubProvider,
      );
    }
  }
}
