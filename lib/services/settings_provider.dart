import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/refresh_schedule.dart';

enum SessionRefreshPolicy {
  none,
  shallow,
  full,
}

enum ListRefreshPolicy {
  none,
  dirty,
  watched,
  quick,
  full,
}

class SettingsProvider extends ChangeNotifier {
  static const String keyRefreshOnOpen = 'refresh_on_open';
  static const String keyRefreshOnMessage = 'refresh_on_message';
  static const String keyRefreshOnReturn = 'refresh_on_return';
  static const String keyRefreshOnCreate = 'refresh_on_create';
  static const String _sessionPageSizeKey = 'session_page_size';
  static const String _refreshSchedulesKey = 'refresh_schedules';

  SessionRefreshPolicy _refreshOnOpen = SessionRefreshPolicy.shallow;
  SessionRefreshPolicy _refreshOnMessage = SessionRefreshPolicy.shallow;
  ListRefreshPolicy _refreshOnReturn = ListRefreshPolicy.dirty;
  ListRefreshPolicy _refreshOnCreate = ListRefreshPolicy.quick;
  int _sessionPageSize = 100;
  List<RefreshSchedule> _schedules = [];
  bool _isInitialized = false;

  SharedPreferences? _prefs;

  SessionRefreshPolicy get refreshOnOpen => _refreshOnOpen;
  SessionRefreshPolicy get refreshOnMessage => _refreshOnMessage;
  ListRefreshPolicy get refreshOnReturn => _refreshOnReturn;
  ListRefreshPolicy get refreshOnCreate => _refreshOnCreate;
  int get sessionPageSize => _sessionPageSize;
  List<RefreshSchedule> get schedules => _schedules;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;

    _refreshOnOpen = _loadEnum(keyRefreshOnOpen, SessionRefreshPolicy.values,
        SessionRefreshPolicy.shallow);
    _refreshOnMessage = _loadEnum(keyRefreshOnMessage,
        SessionRefreshPolicy.values, SessionRefreshPolicy.shallow);
    _refreshOnReturn = _loadEnum(
        keyRefreshOnReturn, ListRefreshPolicy.values, ListRefreshPolicy.dirty);
    _refreshOnCreate = _loadEnum(
        keyRefreshOnCreate, ListRefreshPolicy.values, ListRefreshPolicy.quick);
    _sessionPageSize = _prefs!.getInt(_sessionPageSizeKey) ?? 100;
    _loadSchedules();
    _isInitialized = true;

    notifyListeners();
  }

  T _loadEnum<T extends Enum>(String key, List<T> values, T defaultValue) {
    if (_prefs == null) return defaultValue;
    try {
      final index = _prefs!.getInt(key);
      if (index != null && index >= 0 && index < values.length) {
        return values[index];
      }
    } catch (_) {}
    return defaultValue;
  }

  void _loadSchedules() {
    final jsonString = _prefs?.getString(_refreshSchedulesKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        _schedules =
            decodedList.map((json) => RefreshSchedule.fromJson(json)).toList();
      } catch (e) {
        _schedules = _defaultSchedules();
      }
    } else {
      _schedules = _defaultSchedules();
    }
  }

  Future<void> _saveSchedules() async {
    final jsonString = jsonEncode(_schedules.map((s) => s.toJson()).toList());
    await _prefs?.setString(_refreshSchedulesKey, jsonString);
  }

  List<RefreshSchedule> _defaultSchedules() {
    return [
      RefreshSchedule(
          name: 'Full Refresh',
          intervalInMinutes: 60,
          refreshPolicy: ListRefreshPolicy.full),
      RefreshSchedule(
          name: 'Watched Refresh',
          intervalInMinutes: 5,
          refreshPolicy: ListRefreshPolicy.watched),
      RefreshSchedule(
          name: 'Quick Refresh',
          intervalInMinutes: 15,
          refreshPolicy: ListRefreshPolicy.quick),
    ];
  }

  Future<void> addSchedule(RefreshSchedule schedule) async {
    _schedules.add(schedule);
    await _saveSchedules();
    notifyListeners();
  }

  Future<void> updateSchedule(RefreshSchedule schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      await _saveSchedules();
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String scheduleId) async {
    _schedules.removeWhere((s) => s.id == scheduleId);
    await _saveSchedules();
    notifyListeners();
  }

  Future<void> setSessionPageSize(int size) async {
    if (size < 1) size = 1;
    if (size > 100) size = 100;
    _sessionPageSize = size;
    notifyListeners();
    await _prefs?.setInt(_sessionPageSizeKey, size);
  }

  Future<void> setRefreshOnOpen(SessionRefreshPolicy policy) async {
    _refreshOnOpen = policy;
    notifyListeners();
    await _prefs?.setInt(keyRefreshOnOpen, policy.index);
  }

  Future<void> setRefreshOnMessage(SessionRefreshPolicy policy) async {
    _refreshOnMessage = policy;
    notifyListeners();
    await _prefs?.setInt(keyRefreshOnMessage, policy.index);
  }

  Future<void> setRefreshOnReturn(ListRefreshPolicy policy) async {
    _refreshOnReturn = policy;
    notifyListeners();
    await _prefs?.setInt(keyRefreshOnReturn, policy.index);
  }

  Future<void> setRefreshOnCreate(ListRefreshPolicy policy) async {
    _refreshOnCreate = policy;
    notifyListeners();
    await _prefs?.setInt(keyRefreshOnCreate, policy.index);
  }
}
