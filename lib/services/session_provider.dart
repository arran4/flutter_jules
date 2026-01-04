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
      {bool force = false, String? authToken}) async {
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

      // If valid cache exists and we are not forcing a refresh, stop here.
      if (!force && _items.isNotEmpty) {
        return;
      }
    }

    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      List<Session> allSessions = [];
      String? pageToken;

      // Load all sessions
      do {
        final response = await client.listSessions(
          pageSize: 100, // Fetch larger chunks
          pageToken: pageToken,
          onDebug: (exchange) {
            _lastExchange = exchange;
          },
        );

        allSessions.addAll(response.sessions);
        pageToken = response.nextPageToken;
      } while (pageToken != null);

      if (authToken != null) {
        await _cacheService!.saveSessions(authToken, allSessions);
        _items = await _cacheService!.loadSessions(authToken);
        _sortItems();
      } else {
        // Fallback if no token (shouldn't happen if fetching worked)
      }

      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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
}
