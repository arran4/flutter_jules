import 'package:flutter/material.dart';
import '../models.dart';
import '../models/api_exchange.dart';

import 'jules_client.dart';
import 'cache_service.dart';
import 'github_provider.dart';

class SessionProvider extends ChangeNotifier {
  List<CachedItem<Session>> _items = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  CacheService? _cacheService;
  GithubProvider? _githubProvider;

  List<CachedItem<Session>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;

  void setCacheService(CacheService service) {
    _cacheService = service;
  }

  void setGithubProvider(GithubProvider service) {
    _githubProvider = service;
  }

  Future<void> fetchSessions(
    JulesClient client, {
    bool force = false,
    bool shallow = true,
    int pageSize = 100,
    String? authToken,
    void Function(String)? onRefreshFallback,
  }) async {
    if (_cacheService == null) {
      _error = "Cache service not initialized";
      notifyListeners();
      return;
    }

    // 1. Load from cache immediately
    if (authToken != null) {
      _items = await _cacheService!.loadSessions(authToken);
      _sortItems();
      notifyListeners();

      // If not forced and not shallow, we stop.
      // Ideally we want to refresh if shallow is allowed.
      if (!force && _items.isNotEmpty && !shallow) {
        return;
      }
    }

    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<Session> newSessions = [];
      String? pageToken;

      // Load sessions
      do {
        final response = await client.listSessions(
          pageSize: pageSize,
          pageToken: pageToken,
          onDebug: (exchange) {
            _lastExchange = exchange;
          },
          shouldStop: (shallow && _items.isNotEmpty)
              ? (session) {
                  // Stop if we find this session in our cache with same updateTime/state
                  return _items.any(
                    (existing) =>
                        existing.data.id == session.id &&
                        existing.data.updateTime == session.updateTime &&
                        existing.data.state == session.state,
                  );
                }
              : null,
        );

        newSessions.addAll(response.sessions);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

      // Merge logic
      if (newSessions.isNotEmpty) {
        for (var session in newSessions) {
          final index = _items.indexWhere((i) => i.data.id == session.id);
          final oldItem = index != -1 ? _items[index] : null;
          final oldSession = oldItem?.data;

          // Preserve PR status from cache if backend doesn't provide it
          if (session.prStatus == null && oldSession?.prStatus != null) {
            session = session.copyWith(prStatus: oldSession!.prStatus);
          }

          CacheMetadata metadata;
          if (oldItem != null) {
            _items.removeAt(index);
            
            final changed = (oldSession!.updateTime != session.updateTime) ||
                (oldSession.state != session.state);

            metadata = oldItem.metadata.copyWith(
              lastRetrieved: DateTime.now(),
              lastUpdated:
                  changed ? DateTime.now() : oldItem.metadata.lastUpdated,
            );
          } else {
            metadata = CacheMetadata(
              firstSeen: DateTime.now(),
              lastRetrieved: DateTime.now(),
              lastUpdated: DateTime.now(),
            );
          }
          _items.add(CachedItem(session, metadata));

          // PR Refresh Logic
          if (_githubProvider != null && authToken != null) {
            final prUrl = _getPrUrl(session);
            if (prUrl != null) {
              bool shouldRefresh = false;

              // Rules apply to any session list refresh (full, normal, etc)
              final oldPrUrl = oldSession != null ? _getPrUrl(oldSession) : null;
              final isNewPr = (oldSession == null) || (prUrl != oldPrUrl);

              // 1. New PR Url OR (No Status & No Queue)
              if (isNewPr || (session.prStatus == null && !_isPrFetchQueued(prUrl))) {
                shouldRefresh = true;
              }
              // 2. Status changed to Completed & Has PR
              else if (session.state == SessionState.COMPLETED &&
                  oldSession?.state != SessionState.COMPLETED) {
                shouldRefresh = true;
              }
              // 3. Existing PR status is Draft or Open
              else if (session.prStatus == 'Draft' || session.prStatus == 'Open') {
                shouldRefresh = true;
              }

              if (shouldRefresh) {
                _refreshPrStatusInBackground(session.id, prUrl, authToken);
              }
            }
          }
        }
      }

      if (newSessions.isNotEmpty) {
        // ... logic captured by context ...
      }

      // Update lastRetrieved for all items (especially those skipped by shallow refresh)
      final now = DateTime.now();
      for (var i = 0; i < _items.length; i++) {
        if (now.difference(_items[i].metadata.lastRetrieved).inSeconds > 1) {
          _items[i] = CachedItem(
            _items[i].data,
            _items[i].metadata.copyWith(lastRetrieved: now),
          );
        }
      }

      if (authToken != null) {
        await _cacheService!.saveSessions(authToken, _items);
        _sortItems();
      }

      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      if (shallow && _items.isNotEmpty) {
        final msg = "Shallow refresh failed ($e), switching to full refresh";
        // print(msg);
        if (onRefreshFallback != null) onRefreshFallback(msg);

        _isLoading = false;
        await fetchSessions(
          client,
          force: true,
          shallow: false,
          pageSize: pageSize,
          authToken: authToken,
          onRefreshFallback: onRefreshFallback,
        );
        return;
      }
      _error = e.toString();
    } finally {
      // Ensure we don't double-reset if recursive call handled it
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Manual update from SessionDetailScreen
  Future<void> updateSession(Session session, {String? authToken}) async {
    // Determine metadata
    final index = _items.indexWhere((i) => i.data.name == session.name);
    CacheMetadata metadata;

    if (index != -1) {
      final oldItem = _items[index];
      final changed = (oldItem.data.updateTime != session.updateTime) ||
          (oldItem.data.state != session.state);
      metadata = oldItem.metadata.copyWith(
        lastRetrieved: DateTime.now(),
        lastUpdated: changed ? DateTime.now() : oldItem.metadata.lastUpdated,
      );
    } else {
      metadata = CacheMetadata(
        firstSeen: DateTime.now(),
        lastRetrieved: DateTime.now(),
        lastUpdated: DateTime.now(),
      );
    }

    final cachedItem = CachedItem(session, metadata);

    if (authToken != null && _cacheService != null) {
      await _cacheService!.saveSessions(authToken, [cachedItem]);
    }

    if (index != -1) {
      _items[index] = cachedItem;
    } else {
      _items.add(cachedItem);
    }

    _sortItems();
    notifyListeners();
  }

  Future<void> refreshSession(
    JulesClient client,
    String sessionName, {
    String? authToken,
  }) async {
    try {
      final updatedSession = await client.getSession(sessionName);

      List<Activity>? activities;
      try {
        activities = await client.listActivities(sessionName);
      } catch (e) {
        // print('Failed to preload activities for $sessionName: $e');
      }

      // Determine metadata
      final index = _items.indexWhere((i) => i.data.name == sessionName);
      CacheMetadata metadata;

      if (index != -1) {
        final oldItem = _items[index];
        final changed =
            (oldItem.data.updateTime != updatedSession.updateTime) ||
                (oldItem.data.state != updatedSession.state);
        metadata = oldItem.metadata.copyWith(
          lastRetrieved: DateTime.now(),
          lastUpdated: changed ? DateTime.now() : oldItem.metadata.lastUpdated,
        );
      } else {
        metadata = CacheMetadata(
          firstSeen: DateTime.now(),
          lastRetrieved: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
      }

      if (activities != null) {
        metadata = _resolvePendingMessages(metadata, activities);
      }

      final cachedItem = CachedItem(updatedSession, metadata);

      if (authToken != null && _cacheService != null) {
        await _cacheService!.saveSessions(authToken, [cachedItem]);

        if (activities != null) {
          await _cacheService!.saveSessionDetails(
            authToken,
            updatedSession,
            activities,
          );
        }
      }

      if (index != -1) {
        _items[index] = cachedItem;
      } else {
        _items.add(cachedItem);
      }

      _sortItems();

      if (authToken != null && _githubProvider != null) {
        final prUrl = _getPrUrl(updatedSession);
        if (prUrl != null) {
          _refreshPrStatusInBackground(updatedSession.id, prUrl, authToken);
        }
      }

      notifyListeners();
    } catch (e) {
      // print("Failed to refresh individual session: $e");
      rethrow;
    }
  }

  DateTime _getEffectiveTime(CachedItem<Session> item) {
    if (item.data.updateTime != null) {
      return DateTime.parse(item.data.updateTime!);
    }
    if (item.data.createTime != null) {
      return DateTime.parse(item.data.createTime!);
    }
    return item.metadata.lastRetrieved;
  }

  CacheMetadata _resolvePendingMessages(
    CacheMetadata metadata,
    List<Activity> activities,
  ) {
    if (metadata.pendingMessages.isEmpty) {
      return metadata;
    }

    final newPending = <PendingMessage>[];
    bool changed = false;

    // Latest activity timestamp from server (exclude local?)
    // Activities from server usually have createTime.
    DateTime? latestServerActivityTime;
    for (var a in activities) {
      final t = DateTime.parse(a.createTime);
      if (latestServerActivityTime == null ||
          t.isAfter(latestServerActivityTime)) {
        latestServerActivityTime = t;
      }
    }

    for (var pending in metadata.pendingMessages) {
      // Check for match
      bool matched = activities.any(
        (a) =>
            a.userMessaged != null &&
            a.userMessaged!.userMessage.trim() == pending.content.trim(),
      );

      if (matched) {
        changed = true;
      } else {
        // Not matched. Check for mismatch/stale.
        // If we have newer activities than pending, and it's not matched -> Mismatch
        bool mismatch = pending.hasMismatch;
        if (!mismatch && latestServerActivityTime != null) {
          if (latestServerActivityTime.isAfter(pending.timestamp)) {
            mismatch = true;
            changed = true;
          }
        }
        newPending.add(pending.copyWith(hasMismatch: mismatch));
      }
    }

    if (changed) {
      return metadata.copyWith(
        pendingMessages: newPending,
        hasPendingUpdates: newPending.any((p) => !p.hasMismatch),
      );
    }

    return metadata;
  }

  void _sortItems() {
    _items.sort((a, b) {
      final timeA = _getEffectiveTime(a);
      final timeB = _getEffectiveTime(b);
      return timeB.compareTo(timeA);
    });
  }

  Future<void> refreshDirtySessions(
    JulesClient client, {
    required String authToken,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final dirtyItems = _items.where((item) => _isSessionDirty(item)).toList();
      await Future.wait(
        dirtyItems.map((item) async {
          try {
            // Deep refresh
            await refreshSession(client, item.data.name, authToken: authToken);

            // After successful refresh, clear pending updates flag if it was set
            // We need to fetch the item again from _items because refreshSession replaced it
            final index = _items.indexWhere((i) => i.data.id == item.data.id);
            if (index != -1) {
              final refreshedItem = _items[index];
              if (refreshedItem.metadata.hasPendingUpdates &&
                  refreshedItem.metadata.pendingMessages.isEmpty) {
                final newItem = CachedItem(
                  refreshedItem.data,
                  refreshedItem.metadata.copyWith(hasPendingUpdates: false),
                );
                _items[index] = newItem;
                if (_cacheService != null) {
                  await _cacheService!.saveSessions(authToken, [newItem]);
                }
              }
            }
          } catch (e) {
            // print("Failed to refresh dirty session ${item.data.id}: $e");
          }
        }),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isSessionDirty(CachedItem<Session> item) {
    if (item.data.state == SessionState.IN_PROGRESS) return true; // In Progress
    if (item.metadata.hasPendingUpdates) return true; // Message Sent
    if (item.metadata.isWatched) return true; // Watched
    if (item.metadata.isUpdated) return true; // "Updated" indicator
    return false;
  }

  Future<void> refreshWatchedSessions(
    JulesClient client, {
    required String authToken,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final watchedItems =
          _items.where((item) => item.metadata.isWatched).toList();
      await Future.wait(
        watchedItems.map((item) async {
          try {
            await refreshSession(client, item.data.name, authToken: authToken);
          } catch (e) {
            // Ignore failures for individual sessions
          }
        }),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatch(String sessionId, String authToken) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      final newMetadata = item.metadata.copyWith(
        isWatched: !item.metadata.isWatched,
      );
      final newItem = CachedItem(item.data, newMetadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.saveSessions(authToken, [newItem]);
      }
    }
  }

  Future<void> toggleHidden(String sessionId, String authToken) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      final newMetadata = item.metadata.copyWith(
        isHidden: !item.metadata.isHidden,
      );
      final newItem = CachedItem(item.data, newMetadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.saveSessions(authToken, [newItem]);
      }
    }
  }

  // Called when sending a message
  Future<void> addPendingMessage(
    String sessionId,
    String content,
    String authToken,
  ) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      final newPending = List<PendingMessage>.from(
        item.metadata.pendingMessages,
      );
      newPending.add(
        PendingMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          content: content,
          timestamp: DateTime.now(),
        ),
      );

      final newMetadata = item.metadata.copyWith(
        hasPendingUpdates: true,
        pendingMessages: newPending,
      );
      final newItem = CachedItem(item.data, newMetadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.saveSessions(authToken, [newItem]);
      }
    }
  }

  Future<void> removePendingMessage(
    String sessionId,
    String pendingId,
    String authToken,
  ) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      final newPending = List<PendingMessage>.from(
        item.metadata.pendingMessages,
      );
      newPending.removeWhere((p) => p.id == pendingId);

      final newMetadata = item.metadata.copyWith(
        hasPendingUpdates: newPending.any((p) => !p.hasMismatch),
        pendingMessages: newPending,
      );
      final newItem = CachedItem(item.data, newMetadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.saveSessions(authToken, [newItem]);
      }
    }
  }

  @Deprecated("Use addPendingMessage")
  Future<void> markAsPendingUpdate(String sessionId, String authToken) async {
    // Legacy support, maybe just set flag without content?
    // But we prefer explicit content tracking now.
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      if (!item.metadata.hasPendingUpdates) {
        final newMetadata = item.metadata.copyWith(hasPendingUpdates: true);
        final newItem = CachedItem(item.data, newMetadata);
        _items[index] = newItem;
        notifyListeners();

        if (_cacheService != null) {
          await _cacheService!.saveSessions(authToken, [newItem]);
        }
      }
    }
  }

  Future<void> markAsRead(String sessionId, String authToken) async {
    if (_cacheService != null) {
      await _cacheService!.markSessionAsRead(authToken, sessionId);
      final index = _items.indexWhere((item) => item.data.id == sessionId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = CachedItem(
          item.data,
          item.metadata.copyWith(lastOpened: DateTime.now()),
        );
        notifyListeners();
      }
    }
  }

  Future<void> markAsUnread(String sessionId, String authToken) async {
    if (_cacheService != null) {
      await _cacheService!.markSessionAsUnread(authToken, sessionId);
      final index = _items.indexWhere((item) => item.data.id == sessionId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = CachedItem(
          item.data,
          CacheMetadata(
            firstSeen: item.metadata.firstSeen,
            lastRetrieved: item.metadata.lastRetrieved,
            lastOpened: null,
            lastUpdated: item.metadata.lastUpdated,
            labels: item.metadata.labels,
            isWatched: item.metadata.isWatched,
            hasPendingUpdates: item.metadata.hasPendingUpdates,
          ),
        );
        notifyListeners();
      }
    }
  }

  Future<void> markPrAsOpened(String sessionId, String authToken) async {
    if (_cacheService != null) {
      await _cacheService!.markPrAsOpened(authToken, sessionId);
      final index = _items.indexWhere((item) => item.data.id == sessionId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = CachedItem(
          item.data,
          item.metadata.copyWith(
            lastOpened: DateTime.now(), // it marks as read too
            lastPrOpened: DateTime.now(),
          ),
        );
        notifyListeners();
      }
    }
  }

  /// Refresh the PR status for a session from GitHub
  Future<void> refreshPrStatus(String sessionId, String authToken) async {
    if (_githubProvider == null) {
      throw Exception("GitHub provider not initialized");
    }

    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index == -1) {
      throw Exception("Session not found");
    }

    final session = _items[index].data;
    
    // Check if session has PR output
    if (session.outputs == null || !session.outputs!.any((o) => o.pullRequest != null)) {
      throw Exception("Session does not have a pull request");
    }

    // Get PR URL from session
    final pr = session.outputs!.firstWhere((o) => o.pullRequest != null).pullRequest!;
    
    // Extract owner, repo, and PR number from URL
    // URL format: https://github.com/owner/repo/pull/123
    final uri = Uri.parse(pr.url);
    final pathSegments = uri.pathSegments;
    
    if (pathSegments.length < 4 || pathSegments[pathSegments.length - 2] != 'pull') {
      throw Exception("Invalid PR URL format");
    }

    final owner = pathSegments[0];
    final repo = pathSegments[1];
    final prNumber = pathSegments[pathSegments.length - 1];

    // Fetch PR status from GitHub
    final prStatus = await _githubProvider!.getPrStatus(owner, repo, prNumber);
    
    // Update session with new PR status
    final updatedSession = session.copyWith(prStatus: prStatus);
    
    // Update in cache
    if (_cacheService != null) {
      await _cacheService!.updateSession(authToken, updatedSession);
    }
    
    // Update in memory
    _items[index] = CachedItem(
      updatedSession,
      _items[index].metadata,
    );
    
    notifyListeners();
  }

  String? _getPrUrl(Session session) {
    if (session.outputs != null) {
      for (var o in session.outputs!) {
        if (o.pullRequest != null) return o.pullRequest!.url;
      }
    }
    return null;
  }

  bool _isPrFetchQueued(String prUrl) {
    if (_githubProvider == null) return false;
    
    final uri = Uri.parse(prUrl);
    final pathSegments = uri.pathSegments;
    if (pathSegments.length < 4) return false;

    final owner = pathSegments[0];
    final repo = pathSegments[1];
    final prNumber = pathSegments[pathSegments.length - 1];
    final jobId = 'pr_status_${owner}_${repo}_$prNumber';

    return _githubProvider!.queue.any((job) => job.id == jobId);
  }

  Future<void> _refreshPrStatusInBackground(String sessionId, String prUrl, String authToken) async {
    // Avoid multiple concurrent refreshes for same session if not already queued
    // (This check is redundant if caller checks _isPrFetchQueued, but good for safety)
    if (_isPrFetchQueued(prUrl)) return;

    try {
      final uri = Uri.parse(prUrl);
      final pathSegments = uri.pathSegments;
      final owner = pathSegments[0];
      final repo = pathSegments[1];
      final prNumber = pathSegments[pathSegments.length - 1];

      final status = await _githubProvider!.getPrStatus(owner, repo, prNumber);
      
      if (status != null) {
         // Update session
         final index = _items.indexWhere((i) => i.data.id == sessionId);
         if (index != -1) {
           final item = _items[index];
           if (item.data.prStatus != status) {
             final updatedSession = item.data.copyWith(prStatus: status);
             // Save to cache
             if (_cacheService != null) {
               await _cacheService!.updateSession(authToken, updatedSession);
             }
             // Update memory
             _items[index] = CachedItem(updatedSession, item.metadata);
             notifyListeners();
           }
         }
      }
    } catch (e) {
      // print("Background PR refresh failed: $e");
    }
  }
}
