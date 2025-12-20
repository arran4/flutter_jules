import 'package:flutter/material.dart';
import '../models.dart';
import '../models/api_exchange.dart';
import 'jules_client.dart';

class SessionProvider extends ChangeNotifier {
  List<Session> _sessions = [];
  bool _isFetching = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  String? _nextPageToken;

  List<Session> get sessions => _sessions;
  bool get isFetching => _isFetching;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;
  bool get hasMore => _nextPageToken != null;

  // Cache duration of 2 minutes
  static const Duration _cacheDuration = Duration(minutes: 2);

  Future<void> fetchSessions(JulesClient client,
      {bool force = false, bool loadMore = false}) async {
    // If loading more but no next page, return
    if (loadMore && _nextPageToken == null) return;

    // If not forced/loading more and we have data and it's fresh, don't fetch
    if (!force &&
        !loadMore &&
        _sessions.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    // If already fetching, don't start another fetch unless forced
    if (_isFetching) return;

    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      // If force refresh or initial load, reset paging
      String? pageToken;
      if (loadMore) {
        pageToken = _nextPageToken;
      }

      final response = await client.listSessions(
        pageToken: pageToken,
        onDebug: (exchange) {
          _lastExchange = exchange;
        },
      );

      if (loadMore) {
        _sessions.addAll(response.sessions);
      } else {
        _sessions = response.sessions;
      }
      _nextPageToken = response.nextPageToken;

      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  // Method to manually update local list if needed (e.g. after creation)
  // Or simply force refresh.
  void addSession(Session session) {
    _sessions.insert(0, session);
    notifyListeners();
  }
}
