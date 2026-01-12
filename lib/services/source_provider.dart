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
    SessionProvider? sessionProvider,
    void Function(int loadedCount)? onProgress,
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
        final response = await client.listSources(pageToken: pageToken);
        allSources.addAll(response.sources);
        if (onProgress != null) {
          onProgress(page);
        }

        pageToken = response.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);

      // Enrich with GitHub data if provider is available
      if (githubProvider != null && githubProvider.apiKey != null) {
        List<Source> enrichedSources = [];
        for (final source in allSources) {
          if (source.githubRepo != null) {
            final details = await githubProvider.getRepoDetails(
              source.githubRepo!.owner,
              source.githubRepo!.repo,
            );
            if (details != null) {
              final enrichedRepo = GitHubRepo(
                owner: source.githubRepo!.owner,
                repo: source.githubRepo!.repo,
                isPrivate: source.githubRepo!.isPrivate,
                defaultBranch: source.githubRepo!.defaultBranch,
                branches: source.githubRepo!.branches,
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
              enrichedSources.add(
                Source(
                  name: source.name,
                  id: source.id,
                  githubRepo: enrichedRepo,
                ),
              );
            } else {
              enrichedSources.add(source); // Add original if enrichment fails
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
}
