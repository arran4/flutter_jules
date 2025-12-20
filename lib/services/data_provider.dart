import 'package:flutter/material.dart';
import '../models.dart';
import '../jules_client.dart';

class DataProvider extends ChangeNotifier {
  JulesClient? _client;

  List<Session> _sessions = [];
  List<Source> _sources = [];

  bool _isSessionsLoading = false;
  bool _isSourcesLoading = false;

  String? _sessionsError;
  String? _sourcesError;

  DateTime? _lastSessionsFetch;
  DateTime? _lastSourcesFetch;

  // Getters
  List<Session> get sessions => _sessions;
  List<Source> get sources => _sources;

  bool get isSessionsLoading => _isSessionsLoading;
  bool get isSourcesLoading => _isSourcesLoading;

  String? get sessionsError => _sessionsError;
  String? get sourcesError => _sourcesError;

  void update(JulesClient client) {
    _client = client;
  }

  Future<void> fetchSessions({bool force = false}) async {
    if (_client == null) return;

    if (!force && _lastSessionsFetch != null) {
      final difference = DateTime.now().difference(_lastSessionsFetch!);
      if (difference.inMinutes < 2) {
        return; // Return cached data
      }
    }

    if (_isSessionsLoading) return;

    _isSessionsLoading = true;
    _sessionsError = null;
    notifyListeners();

    try {
      final sessions = await _client!.listSessions();
      _sessions = sessions;
      _lastSessionsFetch = DateTime.now();
    } catch (e) {
      _sessionsError = e.toString();
    } finally {
      _isSessionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSources({bool force = false}) async {
    if (_client == null) return;

    if (!force && _lastSourcesFetch != null) {
      final difference = DateTime.now().difference(_lastSourcesFetch!);
      if (difference.inMinutes < 2) {
        return; // Return cached data
      }
    }

    if (_isSourcesLoading) return;

    _isSourcesLoading = true;
    _sourcesError = null;
    notifyListeners();

    try {
      final sources = await _client!.listSources();
      _sources = sources;
      _lastSourcesFetch = DateTime.now();
    } catch (e) {
      _sourcesError = e.toString();
    } finally {
      _isSourcesLoading = false;
      notifyListeners();
    }
  }
}
