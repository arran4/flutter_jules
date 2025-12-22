import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _sessionPageSizeKey = 'session_page_size';

  int _sessionPageSize = 100;
  bool _isInitialized = false;

  int get sessionPageSize => _sessionPageSize;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionPageSize = prefs.getInt(_sessionPageSizeKey) ?? 100;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setSessionPageSize(int size) async {
    // API limits: default 30, max 100.
    if (size < 1) size = 1;
    if (size > 100) size = 100;

    _sessionPageSize = size;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionPageSizeKey, size);
  }
}
