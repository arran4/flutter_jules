import 'dart:async';

import 'package:flutter/material.dart';
import '../models.dart';
import 'notification_provider.dart';
import 'settings_provider.dart';

import 'jules_client.dart';
import 'cache_service.dart';
import 'github_provider.dart';
import 'exceptions.dart';

class _UpdateEvaluationResult {
  final bool shouldMarkUnread;
  final bool shouldMarkRead;
  final String? reason;

  _UpdateEvaluationResult({
    required this.shouldMarkUnread,
    required this.shouldMarkRead,
    this.reason,
  });
}

class SessionProvider extends ChangeNotifier {
  final GlobalKey<ScaffoldMessengerState> scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  List<CachedItem<Session>> _items = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  String? _lastFetchType;
  CacheService? _cacheService;
  GithubProvider? _githubProvider;
  NotificationProvider? _notificationProvider;
  SettingsProvider? _settingsProvider;
  final StreamController<String> _progressStreamController =
      StreamController<String>.broadcast();

  Stream<String> get progressStream => _progressStreamController.stream;

  List<CachedItem<Session>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;
  String? get lastFetchType => _lastFetchType;

  @override
  void dispose() {
    _progressStreamController.close();
    super.dispose();
  }

  void setCacheService(CacheService service) {
    _cacheService = service;
  }

  void setGithubProvider(GithubProvider service) {
    _githubProvider = service;
  }

  void setNotificationProvider(NotificationProvider service) {
    _notificationProvider = service;
  }

  void setSettingsProvider(SettingsProvider service) {
    _settingsProvider = service;
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
    _progressStreamController.add('Fetching sessions...');
    notifyListeners();

    try {
      List<Session> newSessions = [];
      String? pageToken;
      int pageCount = 0;

      // Load sessions
      do {
        pageCount++;
        if (pageCount > 1) {
          _progressStreamController.add('Fetching page $pageCount...');
        }
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

        // Process new sessions immediately to update UI incrementally
        if (response.sessions.isNotEmpty) {
          _mergeSessions(response.sessions, authToken);
          _sortItems();
          notifyListeners();
        }

        newSessions.addAll(response.sessions);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

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

      _lastFetchType = shallow ? 'Quick' : 'Full';
      _lastFetchTime = DateTime.now();
      _error = null;
      _progressStreamController.add('Refresh complete.');
    } catch (e) {
      if (e is InvalidTokenException) {
        _error = e.toString();
        rethrow;
      }
      _progressStreamController.add('Error: ${e.toString()}');
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
        _progressStreamController.add('Done.');
        notifyListeners();
      }
    }
  }

  void _mergeSessions(List<Session> sessions, String? authToken) {
    if (sessions.isEmpty) return;

    _progressStreamController.add('Merging ${sessions.length} sessions...');
    for (var session in sessions) {
      final index = _items.indexWhere((i) => i.data.id == session.id);
      final oldItem = index != -1 ? _items[index] : null;
      final oldSession = oldItem?.data;

      // Preserve PR status from cache if backend doesn't provide it
      if (oldSession != null) {
        session = session.copyWith(
          prStatus: session.prStatus ?? oldSession.prStatus,
          ciStatus: session.ciStatus ?? oldSession.ciStatus,
          mergeableState: session.mergeableState ?? oldSession.mergeableState,
          additions: session.additions ?? oldSession.additions,
          deletions: session.deletions ?? oldSession.deletions,
          changedFiles: session.changedFiles ?? oldSession.changedFiles,
          diffUrl: session.diffUrl ?? oldSession.diffUrl,
          patchUrl: session.patchUrl ?? oldSession.patchUrl,
        );
      }

      CacheMetadata metadata;
      if (oldItem != null) {
        _items.removeAt(index);

        final evaluation = _evaluateUpdateRules(oldSession, session);

        DateTime? lastUpdated = oldItem.metadata.lastUpdated;
        DateTime? lastOpened = oldItem.metadata.lastOpened;
        String? reasonForLastUnread = oldItem.metadata.reasonForLastUnread;

        if (evaluation.shouldMarkUnread) {
          lastUpdated = DateTime.now();
          if (evaluation.reason != null) {
            reasonForLastUnread = evaluation.reason;
          }
        }
        if (evaluation.shouldMarkRead) {
          lastOpened = DateTime.now();
        }

        metadata = oldItem.metadata.copyWith(
          lastRetrieved: DateTime.now(),
          lastUpdated: lastUpdated,
          lastOpened: lastOpened,
          reasonForLastUnread: reasonForLastUnread,
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
          if (isNewPr ||
              (session.prStatus == null && !_isPrFetchQueued(prUrl))) {
            shouldRefresh = true;
          }
          // 2. Status changed to Completed & Has PR
          else if (session.state == SessionState.COMPLETED &&
              oldSession.state != SessionState.COMPLETED) {
            shouldRefresh = true;
          }
          // 3. Existing PR status is Draft or Open
          else if (session.prStatus == 'Draft' || session.prStatus == 'Open') {
            shouldRefresh = true;
          }

          if (shouldRefresh) {
            _progressStreamController.add(
              'Refreshing Git status for ${session.title ?? session.id}',
            );
            _refreshGitStatusInBackground(session.id, prUrl, authToken);
          }
        }
      }
    }
  }

  // Manual update from SessionDetailScreen
  Future<void> updateSession(
    Session session, {
    String? authToken,
    List<Activity>? activities,
  }) async {
    // Determine metadata
    final index = _items.indexWhere((i) => i.data.name == session.name);
    CacheMetadata metadata;

    if (index != -1) {
      final oldItem = _items[index];
      final evaluation = _evaluateUpdateRules(oldItem.data, session);

      DateTime? lastUpdated = oldItem.metadata.lastUpdated;
      DateTime? lastOpened = oldItem.metadata.lastOpened;
      String? reasonForLastUnread = oldItem.metadata.reasonForLastUnread;

      if (evaluation.shouldMarkUnread) {
        lastUpdated = DateTime.now();
        if (evaluation.reason != null) {
          reasonForLastUnread = evaluation.reason;
        }
      }
      if (evaluation.shouldMarkRead) {
        lastOpened = DateTime.now();
      }

      metadata = oldItem.metadata.copyWith(
        lastRetrieved: DateTime.now(),
        lastUpdated: lastUpdated,
        lastOpened: lastOpened,
        reasonForLastUnread: reasonForLastUnread,
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
      _progressStreamController.add('Refreshing session $sessionName...');
      final updatedSession = await client.getSession(sessionName);

      List<Activity>? activities;
      _progressStreamController.add('Fetching activities for $sessionName...');
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
        final evaluation = _evaluateUpdateRules(oldItem.data, updatedSession);

        DateTime? lastUpdated = oldItem.metadata.lastUpdated;
        DateTime? lastOpened = oldItem.metadata.lastOpened;
        String? reasonForLastUnread = oldItem.metadata.reasonForLastUnread;

        if (evaluation.shouldMarkUnread) {
          lastUpdated = DateTime.now();
          if (evaluation.reason != null) {
            reasonForLastUnread = evaluation.reason;
          }
        }
        if (evaluation.shouldMarkRead) {
          lastOpened = DateTime.now();
        }

        metadata = oldItem.metadata.copyWith(
          lastRetrieved: DateTime.now(),
          lastUpdated: lastUpdated,
          lastOpened: lastOpened,
          reasonForLastUnread: reasonForLastUnread,
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
          _progressStreamController.add(
            'Refreshing Git status for ${updatedSession.title ?? updatedSession.id}',
          );
          _refreshGitStatusInBackground(updatedSession.id, prUrl, authToken);
        }
      }

      _progressStreamController.add('Session refreshed.');
      notifyListeners();
    } catch (e) {
      _progressStreamController.add('Error: ${e.toString()}');
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

  _UpdateEvaluationResult _evaluateUpdateRules(
    Session? oldSession,
    Session newSession,
  ) {
    if (oldSession == null) {
      return _UpdateEvaluationResult(
        shouldMarkUnread: true,
        shouldMarkRead: false,
        reason: "New session",
      );
    }

    final reasons = <String>[];
    bool shouldMarkUnread = false;
    bool shouldMarkRead = false;

    // 1. Check Intrinsic Jules Progress (Always Unread)
    if (oldSession.state != newSession.state) {
      final oldState = oldSession.state.toString().split('.').last;
      final newState = newSession.state.toString().split('.').last;
      reasons.add("Status changed from $oldState to $newState");
      shouldMarkUnread = true;
    }

    bool julesProgress = (oldSession.currentStep != newSession.currentStep) ||
        (oldSession.currentAction != newSession.currentAction);
    if (julesProgress) {
      reasons.add("Session progressed");
      shouldMarkUnread = true;
    }

    // 2. Evaluate User Rules
    final rules = _settingsProvider?.unreadRules ?? [];
    for (var rule in rules) {
      if (!rule.enabled) continue;

      bool matched = false;
      String? ruleReason;

      switch (rule.type) {
        case RuleType.prStatus:
          final oldPr = oldSession.prStatus ?? 'None';
          final newPr = newSession.prStatus ?? 'None';
          if (oldPr != newPr) {
            matched = _matchesTransition(rule, oldPr, newPr);
            if (matched) {
              ruleReason = "PR Status changed from $oldPr to $newPr";
            }
          }
          break;
        case RuleType.ciStatus:
          final oldCi = oldSession.ciStatus ?? 'None';
          final newCi = newSession.ciStatus ?? 'None';
          if (oldCi != newCi) {
            matched = _matchesTransition(rule, oldCi, newCi);
            if (matched) {
              ruleReason = "CI Status changed from $oldCi to $newCi";
            }
          }
          break;
        // case RuleType.sessionState:
        //   final oldState = oldSession.state.toString().split('.').last;
        //   final newState = newSession.state.toString().split('.').last;
        //   if (oldState != newState) {
        //     matched = _matchesTransition(rule, oldState, newState);
        //     if (matched) {
        //       ruleReason = "State changed from $oldState to $newState";
        //     }
        //   }
        //   break;
        case RuleType.contentUpdate:
          if (oldSession.updateTime != newSession.updateTime) {
            matched = true;
            ruleReason = "Session updated";
          }
          break;
      }

      if (matched) {
        if (rule.action == RuleAction.markUnread) {
          shouldMarkUnread = true;
          if (ruleReason != null) reasons.add(ruleReason);
        } else if (rule.action == RuleAction.markRead) {
          shouldMarkRead = true;
        }
      }
    }

    if (reasons.isEmpty && shouldMarkUnread) {
      reasons.add("Session updated");
    }

    return _UpdateEvaluationResult(
      shouldMarkUnread: shouldMarkUnread,
      shouldMarkRead: shouldMarkRead,
      reason: reasons.isNotEmpty ? reasons.join(". ") : null,
    );
  }

  bool _matchesTransition(UnreadRule rule, String oldValue, String newValue) {
    if (rule.fromValue != null &&
        rule.fromValue!.isNotEmpty &&
        rule.fromValue != oldValue) {
      return false;
    }
    if (rule.toValue != null &&
        rule.toValue!.isNotEmpty &&
        rule.toValue != newValue) {
      return false;
    }
    return true;
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
        if (!mismatch &&
            latestServerActivityTime != null &&
            pending.status != PendingMessageStatus.sent) {
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

  Future<void> watchSession(String sessionId, String authToken) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      if (item.metadata.isWatched) return;

      final newMetadata = item.metadata.copyWith(isWatched: true);
      final newItem = CachedItem(item.data, newMetadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.saveSessions(authToken, [newItem]);
      }
    }
  }

  Future<void> unwatchSession(String sessionId, String authToken) async {
    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index != -1) {
      final item = _items[index];
      if (!item.metadata.isWatched) return;

      final newMetadata = item.metadata.copyWith(isWatched: false);
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
  Future<String?> addPendingMessage(
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
      final pendingId = DateTime.now().microsecondsSinceEpoch.toString();
      newPending.add(
        PendingMessage(
          id: pendingId,
          content: content,
          timestamp: DateTime.now(),
          status: PendingMessageStatus.sending,
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
      return pendingId;
    }
    return null;
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

  Future<void> markMessageAsSent(
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
      final pendingIndex = newPending.indexWhere((p) => p.id == pendingId);

      if (pendingIndex != -1) {
        newPending[pendingIndex] = newPending[pendingIndex].copyWith(
          status: PendingMessageStatus.sent,
        );

        final newMetadata = item.metadata.copyWith(pendingMessages: newPending);
        final newItem = CachedItem(item.data, newMetadata);
        _items[index] = newItem;
        notifyListeners();

        if (_cacheService != null) {
          await _cacheService!.saveSessions(authToken, [newItem]);
        }
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
            reasonForLastUnread: "Marked as unread manually",
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

  /// Refresh the PR and CI status for a session from GitHub
  Future<void> refreshGitStatus(String sessionId, String authToken) async {
    if (_githubProvider == null) {
      throw Exception("GitHub provider not initialized");
    }

    final index = _items.indexWhere((item) => item.data.id == sessionId);
    if (index == -1) {
      throw Exception("Session not found");
    }

    final session = _items[index].data;

    // Check if session has PR output
    if (session.outputs == null ||
        !session.outputs!.any((o) => o.pullRequest != null)) {
      throw Exception("Session does not have a pull request");
    }

    // Get PR URL from session
    final pr =
        session.outputs!.firstWhere((o) => o.pullRequest != null).pullRequest!;

    // Extract owner, repo, and PR number from URL
    // URL format: https://github.com/owner/repo/pull/123
    final uri = Uri.parse(pr.url);
    final pathSegments = uri.pathSegments;
    var pullIndex = pathSegments.lastIndexOf('pull');
    if (pullIndex == -1) {
      pullIndex = pathSegments.lastIndexOf('pulls');
    }

    if (pullIndex == -1 || pullIndex < 2) {
      throw Exception(
        "Invalid PR URL format: 'pull' or 'pulls' segment not found or misplaced.",
      );
    }

    final owner = pathSegments[pullIndex - 2];
    final repo = pathSegments[pullIndex - 1];
    final prNumber = pathSegments[pathSegments.length - 1];

    // Fetch PR and CI statuses from GitHub in parallel
    final results = await Future.wait([
      _githubProvider!.getPrStatus(owner, repo, prNumber),
      _githubProvider!.getCIStatus(owner, repo, prNumber),
    ]);

    Object? result0 = results[0];
    GitHubPrResponse? prResponse;
    String? rawPrStatus;

    if (result0 is GitHubPrResponse) {
      prResponse = result0;
    } else if (result0 is String) {
      debugPrint('Warning: getPrStatus returned String: $result0');
      rawPrStatus = result0;
    } else if (result0 is Map<String, dynamic>) {
      // debugPrint('Warning: getPrStatus returned Map');
      // Backward compatibility if needed
      prResponse = GitHubPrResponse(result0);
    }

    final ciStatus = results[1] as String?;

    // Update session with new statuses
    final updatedSession = session.copyWith(
      prStatus: prResponse?.displayStatus ?? rawPrStatus ?? session.prStatus,
      ciStatus: ciStatus ?? session.ciStatus,
      mergeableState: prResponse?.mergeableState,
      additions: prResponse?.additions,
      deletions: prResponse?.deletions,
      changedFiles: prResponse?.changedFiles,
      diffUrl: prResponse?.diffUrl,
      patchUrl: prResponse?.patchUrl,
    );

    final evaluation = _evaluateUpdateRules(session, updatedSession);
    var metadata = _items[index].metadata;

    DateTime? lastUpdated = metadata.lastUpdated;
    DateTime? lastOpened = metadata.lastOpened;
    String? reasonForLastUnread = metadata.reasonForLastUnread;

    if (evaluation.shouldMarkUnread) {
      lastUpdated = DateTime.now();
      if (evaluation.reason != null) {
        reasonForLastUnread = evaluation.reason;
      }
    }
    if (evaluation.shouldMarkRead) {
      lastOpened = DateTime.now();
    }

    metadata = metadata.copyWith(
      lastUpdated: lastUpdated,
      lastOpened: lastOpened,
      reasonForLastUnread: reasonForLastUnread,
    );

    final newItem = CachedItem(updatedSession, metadata);

    // Update in cache
    if (_cacheService != null) {
      await _cacheService!.saveSessions(authToken, [newItem]);
    }

    // Update in memory
    _items[index] = newItem;

    notifyListeners();
  }

  Future<void> updateSessionTags(Session session, List<String> tags) async {
    final index = _items.indexWhere((i) => i.data.id == session.id);
    if (index != -1) {
      final item = _items[index];
      final updatedSession = item.data.copyWith(tags: tags);
      final newItem = CachedItem(updatedSession, item.metadata);
      _items[index] = newItem;
      notifyListeners();

      if (_cacheService != null) {
        await _cacheService!.updateSession(
          (await _githubProvider!.getToken())!,
          updatedSession,
        );
      }
    }
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
    var pullIndex = pathSegments.lastIndexOf('pull');
    if (pullIndex == -1) {
      pullIndex = pathSegments.lastIndexOf('pulls');
    }

    if (pullIndex == -1 || pullIndex < 2) {
      return false;
    }

    final owner = pathSegments[pullIndex - 2];
    final repo = pathSegments[pullIndex - 1];
    final prNumber = pathSegments[pathSegments.length - 1];
    final jobId = 'pr_status_${owner}_${repo}_$prNumber';

    return _githubProvider!.queue.any((job) => job.id == jobId);
  }

  Future<void> _refreshGitStatusInBackground(
    String sessionId,
    String prUrl,
    String authToken,
  ) async {
    // Avoid multiple concurrent refreshes for same session if not already queued
    if (_isPrFetchQueued(prUrl)) return;

    try {
      final uri = Uri.parse(prUrl);
      final pathSegments = uri.pathSegments;
      var pullIndex = pathSegments.lastIndexOf('pull');
      if (pullIndex == -1) {
        pullIndex = pathSegments.lastIndexOf('pulls');
      }

      if (pullIndex == -1 || pullIndex < 2) {
        throw Exception(
          "Invalid PR URL format: 'pull' or 'pulls' segment not found or misplaced.",
        );
      }
      final owner = pathSegments[pullIndex - 2];
      final repo = pathSegments[pullIndex - 1];
      final prNumber = pathSegments[pathSegments.length - 1];

      // Fetch statuses in parallel
      final results = await Future.wait([
        _githubProvider!.getPrStatus(owner, repo, prNumber),
        _githubProvider!.getCIStatus(owner, repo, prNumber),
      ]);

      Object? result0 = results[0];
      GitHubPrResponse? prResponse;
      String? rawPrStatus;

      if (result0 is GitHubPrResponse) {
        prResponse = result0;
      } else if (result0 is String) {
        // debugPrint('Warning: background getPrStatus returned String: $result0');
        rawPrStatus = result0;
      } else if (result0 is Map<String, dynamic>) {
        prResponse = GitHubPrResponse(result0);
      }

      final ciStatus = results[1] as String?;

      if (prResponse != null || ciStatus != null || rawPrStatus != null) {
        // Update session
        final index = _items.indexWhere((i) => i.data.id == sessionId);
        if (index != -1) {
          final item = _items[index];

          final updatedSession = item.data.copyWith(
            prStatus:
                prResponse?.displayStatus ?? rawPrStatus ?? item.data.prStatus,
            ciStatus: ciStatus ?? item.data.ciStatus,
            mergeableState: prResponse?.mergeableState,
            additions: prResponse?.additions,
            deletions: prResponse?.deletions,
            changedFiles: prResponse?.changedFiles,
            diffUrl: prResponse?.diffUrl,
            patchUrl: prResponse?.patchUrl,
          );

          final evaluation = _evaluateUpdateRules(item.data, updatedSession);
          var metadata = item.metadata;

          DateTime? lastUpdated = metadata.lastUpdated;
          DateTime? lastOpened = metadata.lastOpened;
          String? reasonForLastUnread = metadata.reasonForLastUnread;

          if (evaluation.shouldMarkUnread) {
            lastUpdated = DateTime.now();
            if (evaluation.reason != null) {
              reasonForLastUnread = evaluation.reason;
            }
          }
          if (evaluation.shouldMarkRead) {
            lastOpened = DateTime.now();
          }

          metadata = metadata.copyWith(
            lastUpdated: lastUpdated,
            lastOpened: lastOpened,
            reasonForLastUnread: reasonForLastUnread,
          );

          final newItem = CachedItem(updatedSession, metadata);

          // Save to cache
          if (_cacheService != null) {
            await _cacheService!.saveSessions(authToken, [newItem]);
          }
          // Update memory
          _items[index] = newItem;
          notifyListeners();
        }
      }
    } catch (e) {
      if (e is GithubApiException) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          _notificationProvider?.addNotification(
            NotificationMessage(
              id: 'github-auth-error',
              title: 'GitHub Authentication Error',
              message:
                  'Failed to fetch data from GitHub. Your PAT may be invalid or expired.',
              type: NotificationType.error,
              actionLabel: 'Update PAT',
              actionType: NotificationActionType.showGithubPatDialog,
            ),
          );
        } else {
          // Other API errors (like 404 Not Found)
          debugPrint(
            "Background Git status refresh failed for session $sessionId, pr $prUrl: $e${e.context != null ? ' Context: ${e.context}' : ''}",
          );
        }
      } else if (e is JulesException) {
        debugPrint(
          "Background Git status refresh failed for session $sessionId, pr $prUrl: $e${e.context != null ? ' Context: ${e.context}' : ''}",
        );
      } else {
        // Other general errors
        debugPrint(
          "Background Git status refresh failed for session $sessionId, pr $prUrl: $e",
        );
      }
    }
  }

  Future<void> refreshSessionsForSource(
    JulesClient client,
    String sourceName, {
    required String authToken,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final sourceSessions = _items
          .where((item) => item.data.sourceContext?.source == sourceName)
          .toList();

      if (sourceSessions.isEmpty) {
        return;
      }

      await Future.wait(
        sourceSessions.map(
          (item) =>
              refreshSession(client, item.data.name, authToken: authToken),
        ),
      );
    } catch (e) {
      debugPrint("Failed to refresh sessions for source $sourceName: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
