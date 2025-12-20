import 'package:flutter/material.dart';
import '../models.dart';
import '../models/api_exchange.dart';
import 'jules_client.dart';

class SessionProvider extends ChangeNotifier {
  List<Session> _sessions = [];
  List<Source> _sources = [];
  bool _isFetching = false;
  bool _isFetchingSources = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  DateTime? _lastSourceFetchTime;

  List<Session> get sessions => _sessions;
  List<Source> get sources => _sources;
  bool get isFetching => _isFetching;
  bool get isFetchingSources => _isFetchingSources;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;
  DateTime? get lastSourceFetchTime => _lastSourceFetchTime;

  // Cache duration of 2 minutes
  static const Duration _cacheDuration = Duration(minutes: 2);

  Future<void> fetchSessions(JulesClient client, {bool force = false}) async {
    // If not forced and we have data and it's fresh, don't fetch
    if (!force &&
        _sessions.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return;
    }

    // If already fetching, don't start another fetch unless forced (which might mean cancel/restart, but simplest is just return)
    if (_isFetching) return;

    _isFetching = true;
    _error = null;
    notifyListeners();

    try {
      final sessions = await client.listSessions(
        onDebug: (exchange) {
          _lastExchange = exchange;
        },
      );
      _sessions = sessions;
      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> fetchSources(JulesClient client, {bool force = false}) async {
    // Cache duration for sources (e.g. 10 minutes)
    const sourceCacheDuration = Duration(minutes: 10);

    if (!force &&
        _sources.isNotEmpty &&
        _lastSourceFetchTime != null &&
        DateTime.now().difference(_lastSourceFetchTime!) < sourceCacheDuration) {
      return;
    }

    if (_isFetchingSources) return;

    _isFetchingSources = true;
    _error = null;
    notifyListeners();

    try {
      final sources = await client.listSources(
        onDebug: (exchange) {
          _lastExchange = exchange;
        },
      );
      _sources = sources;
      _lastSourceFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetchingSources = false;
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
