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

  List<Session> get sessions => _sessions;
  bool get isFetching => _isFetching;
  String? get error => _error;
  ApiExchange? get lastExchange => _lastExchange;
  DateTime? get lastFetchTime => _lastFetchTime;

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

  // Method to manually update local list if needed (e.g. after creation)
  // Or simply force refresh.
  void addSession(Session session) {
    _sessions.insert(0, session);
    notifyListeners();
  }
}
