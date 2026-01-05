import 'package:flutter/material.dart';
import '../models.dart';
import '../models/api_exchange.dart';
import '../models/cache_metadata.dart';
import 'jules_client.dart';
import 'cache_service.dart';

class SessionProvider extends ChangeNotifier {
  List<CachedItem<Session>> _items = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  CacheService? _cacheService;

  List<CachedItem<Session>> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;

  void setCacheService(CacheService service) {
    _cacheService = service;
  }

  Future<void> fetchSessions(JulesClient client,
      {bool force = false,
      bool shallow = true,
      String? authToken,
      void Function(String)? onRefreshFallback}) async {
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
          pageSize: 100,
          pageToken: pageToken,
          onDebug: (exchange) {
            _lastExchange = exchange;
          },
          shouldStop: (shallow && _items.isNotEmpty)
              ? (session) {
                  // Stop if we find this session in our cache with same updateTime/state
                  return _items.any((existing) =>
                      existing.data.id == session.id &&
                      existing.data.updateTime == session.updateTime &&
                      existing.data.state == session.state);
                }
              : null,
        );

        newSessions.addAll(response.sessions);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

      // Merge logic
      if (newSessions.isNotEmpty) {
        for (final session in newSessions) {
          final index = _items.indexWhere((i) => i.data.id == session.id);
          CacheMetadata metadata;

          if (index != -1) {
            final oldItem = _items[index];
            _items.removeAt(index);

            final changed = (oldItem.data.updateTime != session.updateTime) ||
                (oldItem.data.state != session.state);

            metadata = oldItem.metadata.copyWith(
                lastRetrieved: DateTime.now(),
                lastUpdated:
                    changed ? DateTime.now() : oldItem.metadata.lastUpdated);
          } else {
            metadata = CacheMetadata(
                firstSeen: DateTime.now(),
                lastRetrieved: DateTime.now(),
                lastUpdated: DateTime.now());
          }
          _items.add(CachedItem(session, metadata));
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
              _items[i].data, _items[i].metadata.copyWith(lastRetrieved: now));
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
        print(msg);
        if (onRefreshFallback != null) onRefreshFallback(msg);

        _isLoading = false;
        await fetchSessions(client,
            force: true,
            shallow: false,
            authToken: authToken,
            onRefreshFallback: onRefreshFallback);
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

  Future<void> refreshSession(JulesClient client, String sessionName,
      {String? authToken}) async {
    try {
      final updatedSession = await client.getSession(sessionName);

      List<Activity>? activities;
      try {
        activities = await client.listActivities(sessionName);
      } catch (e) {
        print('Failed to preload activities for $sessionName: $e');
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
            lastUpdated:
                changed ? DateTime.now() : oldItem.metadata.lastUpdated);
      } else {
        metadata = CacheMetadata(
            firstSeen: DateTime.now(),
            lastRetrieved: DateTime.now(),
            lastUpdated: DateTime.now());
      }

      final cachedItem = CachedItem(updatedSession, metadata);

      if (authToken != null && _cacheService != null) {
        await _cacheService!.saveSessions(authToken, [cachedItem]);

        if (activities != null) {
          await _cacheService!
              .saveSessionDetails(authToken, updatedSession, activities);
        }
      }

      if (index != -1) {
        _items[index] = cachedItem;
      } else {
        _items.add(cachedItem);
      }

      _sortItems();
      notifyListeners();
    } catch (e) {
      print("Failed to refresh individual session: $e");
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

  void _sortItems() {
    _items.sort((a, b) {
      final timeA = _getEffectiveTime(a);
      final timeB = _getEffectiveTime(b);
      return timeB.compareTo(timeA);
    });
  }

  Future<void> markAsRead(String sessionId, String authToken) async {
    if (_cacheService != null) {
      await _cacheService!.markSessionAsRead(authToken, sessionId);
      final index = _items.indexWhere((item) => item.data.id == sessionId);
      if (index != -1) {
        final item = _items[index];
        _items[index] = CachedItem(
            item.data, item.metadata.copyWith(lastOpened: DateTime.now()));
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
            ));
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
            ));
        notifyListeners();
      }
    }
  }
}
