import 'package:flutter/material.dart';
import '../models.dart';
import 'jules_client.dart';

class SourceProvider extends ChangeNotifier {
  List<Source> _sources = [];
  bool _isFetching = false;
  String? _error;
  DateTime? _lastFetchTime;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _fetchComplete = false;

  List<Source> get sources => _sources;
  bool get isFetching => _isFetching;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get fetchComplete => _fetchComplete;

  // Cache duration (e.g. 5 minutes or longer as requested)
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<void> fetchSources(JulesClient client, {bool force = false}) async {
    // If not forced and we have data and it's fresh, don't fetch
    if (!force &&
        _sources.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    if (_isFetching) return;

    _isFetching = true;
    _fetchComplete = false;
    _error = null;
    _currentPage = 0;
    _totalPages = 0;
    notifyListeners();

    try {
      final allSources = <Source>[];
      String? pageToken;
      int pageCount = 0;
      
      do {
        final response = await client.listSources(pageToken: pageToken);
        allSources.addAll(response.sources);
        pageToken = response.nextPageToken;
        pageCount++;
        
        // Update progress and sources incrementally
        _currentPage = pageCount;
        _sources = List.from(allSources); // Create a new list to trigger UI updates
        notifyListeners();
        
      } while (pageToken != null && pageToken.isNotEmpty);

      _totalPages = pageCount;
      _sources = allSources;
      _lastFetchTime = DateTime.now();
      _error = null;
      _fetchComplete = true;
    } catch (e) {
      _error = e.toString();
      _fetchComplete = false;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
