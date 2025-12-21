import 'package:flutter/material.dart';
import '../models.dart';
import 'jules_client.dart';

class SourceProvider extends ChangeNotifier {
  List<Source> _sources = [];
  bool _isFetching = false;
  bool _isRefreshing = false;
  String? _error;
  DateTime? _lastFetchTime;
  int _currentPage = 0;
  bool _hasMorePages = true;
  String? _nextPageToken;
  bool _initialLoadComplete = false;

  List<Source> get sources => _sources;
  bool get isFetching => _isFetching;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get currentPage => _currentPage;
  bool get hasMorePages => _hasMorePages;
  bool get initialLoadComplete => _initialLoadComplete;

  // Cache duration
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Load initial page in background (called on app start)
  Future<void> loadInitialPage(JulesClient client) async {
    // If we already have cached data that's fresh, don't reload
    if (_sources.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    if (_isFetching) return;

    _isFetching = true;
    _error = null;
    _currentPage = 0;
    _hasMorePages = true;
    _nextPageToken = null;
    notifyListeners();

    try {
      final response = await client.listSources();
      _sources = response.sources;
      _nextPageToken = response.nextPageToken;
      _hasMorePages = _nextPageToken != null && _nextPageToken!.isNotEmpty;
      _currentPage = 1;
      _lastFetchTime = DateTime.now();
      _initialLoadComplete = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _initialLoadComplete = false;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Load next page (on-demand, e.g., when scrolling or searching)
  Future<void> loadNextPage(JulesClient client) async {
    if (_isFetching || !_hasMorePages || _nextPageToken == null) return;

    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      final response = await client.listSources(pageToken: _nextPageToken);
      _sources.addAll(response.sources);
      _nextPageToken = response.nextPageToken;
      _hasMorePages = _nextPageToken != null && _nextPageToken!.isNotEmpty;
      _currentPage++;
      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Refresh all sources (keeps old data visible during refresh)
  Future<void> refresh(JulesClient client) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      final newSources = <Source>[];
      String? pageToken;
      int pageCount = 0;

      // Load all pages
      do {
        final response = await client.listSources(pageToken: pageToken);
        newSources.addAll(response.sources);
        pageToken = response.nextPageToken;
        pageCount++;
      } while (pageToken != null && pageToken.isNotEmpty);

      // Only update sources after all pages are loaded
      _sources = newSources;
      _currentPage = pageCount;
      _nextPageToken = null;
      _hasMorePages = false;
      _lastFetchTime = DateTime.now();
      _initialLoadComplete = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Load all remaining pages (e.g., when user searches)
  Future<void> loadAllPages(JulesClient client) async {
    while (_hasMorePages && !_isFetching) {
      await loadNextPage(client);
    }
  }
}
