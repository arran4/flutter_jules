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
      // Chain session fetch if requested
      if (sessionProvider != null) {
        // We don't wait for it here, but we trigger it.
        // Let UI handle loading state of sessions.
        unawaited(
          sessionProvider.fetchSessions(
            client,
            authToken: authToken,
            force: true,
          ),
        );
      }

      List<Source> allSources = [];
      String? pageToken;

      do {
        final response = await client.listSources(pageToken: pageToken);
        allSources.addAll(response.sources);
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

  /// Refreshes data for a single source.
  /// Currently this re-enriches the source with GitHub details.
  Future<void> refreshSource(
    Source source,
    GithubProvider githubProvider,
    String? authToken,
  ) async {
    if (source.githubRepo == null) return;

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

      final newSource = Source(
        name: source.name,
        id: source.id,
        githubRepo: enrichedRepo,
      );

      final index = _items.indexWhere((i) => i.data.name == source.name);
      if (index != -1) {
        final oldItem = _items[index];
        final newItem = CachedItem(
          newSource,
          oldItem.metadata.copyWith(lastRetrieved: DateTime.now()),
        );
        _items[index] = newItem;
        notifyListeners();

        if (_cacheService != null && authToken != null) {
          // We can't save just one source easily if `saveSources` overwrites all.
          // But `saveSources` takes a list. If we assume the list is complete, we can save it.
          // Since _items is the complete list, we can save it.
          await _cacheService!.saveSources(
            authToken,
            _items.map((i) => i.data).toList(),
          );
        }
      }
    }
  }
}
