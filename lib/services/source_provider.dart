import 'package:flutter/material.dart';
import '../models.dart';
import '../models/cache_metadata.dart';
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

  Future<void> fetchSources(JulesClient client, {String? authToken}) async {
    if (_cacheService != null && authToken != null) {
      _items = await _cacheService!.loadSources(authToken);
      notifyListeners();
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
        _items = allSources.map((s) => CachedItem(s, CacheMetadata(firstSeen: now, lastRetrieved: now))).toList();
      }

      _lastFetchTime = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
