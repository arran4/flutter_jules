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

  Future<void> fetchSources(JulesClient client,
      {bool force = false, String? authToken}) async {
    // 1. Initial Load from Cache
    if (_cacheService != null && authToken != null) {
      _items = await _cacheService!.loadSources(authToken);
      notifyListeners();

      // If we have data and not forcing, we can check if we should skip fetch
      // But user requirement says: "until we manually refresh... OR if it sees a source it hasn't seen before"
      // In the context of "sees a source it hasn't seen before", this usually implies
      // checking against a known set (e.g. from session list source contexts).
      // However, strictly "until we manually refresh" implies we should obey 'force'
      // If not forced and we have items, we stop.
      if (!force && _items.isNotEmpty) {
        return;
      }
    }

    if (_isLoading) return;
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

      if (_cacheService != null && authToken != null) {
        await _cacheService!.saveSources(authToken, allSources);
        _items = await _cacheService!.loadSources(authToken);
      } else {
        final now = DateTime.now();
        _items = allSources
            .map((s) => CachedItem(
                s, CacheMetadata(firstSeen: now, lastRetrieved: now)))
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
  Future<void> ensureSourceAvailable(JulesClient client, String sourceName,
      {String? authToken}) async {
    // Check if we already have it
    final exists = _items.any(
        (item) => item.data.name == sourceName || item.data.id == sourceName);
    if (!exists) {
      // Trigger non-forced refresh (actually forced to ensure we get new data,
      // but 'force' arg in our fetchSources logic currently acts as "always fetch").
      // We will call fetchSources with force=true to get latest list which hopefully contains the new source.
      await fetchSources(client, force: true, authToken: authToken);
    }
  }
}
