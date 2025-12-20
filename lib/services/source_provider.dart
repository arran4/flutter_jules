import 'package:flutter/material.dart';
import '../models.dart';
import 'jules_client.dart';

class SourceProvider extends ChangeNotifier {
  List<Source> _sources = [];
  bool _isFetching = false;
  String? _error;
  DateTime? _lastFetchTime;

  List<Source> get sources => _sources;
  bool get isFetching => _isFetching;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;

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
    _error = null;
    notifyListeners();

    try {
      final sources = await client.listSources();
      _sources = sources;
      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
