import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../models/bulk_action.dart';
import '../models/refresh_schedule.dart';

enum SessionRefreshPolicy { none, shallow, full }

enum ListRefreshPolicy { none, dirty, watched, quick, full }

enum FabVisibility { appBar, floating, off }

class SettingsProvider extends ChangeNotifier {
  static const String keyRefreshOnOpen = 'refresh_on_open';
  static const String keyRefreshOnMessage = 'refresh_on_message';
  static const String keyRefreshOnReturn = 'refresh_on_return';
  static const String keyRefreshOnCreate = 'refresh_on_create';
  static const String _sessionPageSizeKey = 'session_page_size';
  static const String _refreshSchedulesKey = 'refresh_schedules';
  static const String keyNotifyOnAttention = 'notify_on_attention';
  static const String keyNotifyOnCompletion = 'notify_on_completion';
  static const String keyNotifyOnWatch = 'notify_on_watch';
  static const String keyNotifyOnFailure = 'notify_on_failure';
  static const String _bulkActionConfigKey = 'bulk_action_config';
  static const String _lastFilterKey = 'last_filter';
  static const String keyTrayEnabled = 'tray_enabled';
  static const String keyFabVisibility = 'fab_visibility';
  static const String keyHideArchivedAndReadOnly =
      'hide_archived_and_read_only';

  // Keybindings
  static const String keyEnterKeyAction = 'enter_key_action';
  static const String keyShiftEnterKeyAction = 'shift_enter_key_action';
  static const String keyCtrlEnterKeyAction = 'ctrl_enter_key_action';
  static const String keyCtrlShiftEnterKeyAction =
      'ctrl_shift_enter_key_action';
  static const String keyEscKeyAction = 'esc_key_action';

  // Filter Memory
  FilterElement? _lastFilter;

  // Bulk Action Memory
  List<BulkActionStep> _lastBulkActions = [];
  int _lastBulkParallelQueries = 1;
  int _lastBulkWaitBetweenSeconds = 2;
  int? _lastBulkLimit;
  int _lastBulkOffset = 0;
  bool _lastBulkRandomize = false;
  bool _lastBulkStopOnError = false;

  SessionRefreshPolicy _refreshOnOpen = SessionRefreshPolicy.shallow;
  SessionRefreshPolicy _refreshOnMessage = SessionRefreshPolicy.shallow;
  ListRefreshPolicy _refreshOnReturn = ListRefreshPolicy.dirty;
  ListRefreshPolicy _refreshOnCreate = ListRefreshPolicy.quick;
  int _sessionPageSize = 100;
  List<RefreshSchedule> _schedules = [];
  bool _isInitialized = false;
  bool _notifyOnAttention = true;
  bool _notifyOnCompletion = true;
  bool _notifyOnWatch = true;
  bool _notifyOnFailure = true;
  bool _trayEnabled = false;
  FabVisibility _fabVisibility = FabVisibility.floating;
  bool _hideArchivedAndReadOnly = true;

  // Keybinding Actions
  MessageSubmitAction _enterKeyAction = MessageSubmitAction.addNewLine;
  MessageSubmitAction _shiftEnterKeyAction = MessageSubmitAction.addNewLine;
  MessageSubmitAction _ctrlEnterKeyAction = MessageSubmitAction.submitsMessage;
  MessageSubmitAction _ctrlShiftEnterKeyAction =
      MessageSubmitAction.submitsMessageAndGoesBack;
  EscKeyAction _escKeyAction = EscKeyAction.doesNothing;

  SharedPreferences? _prefs;

  SessionRefreshPolicy get refreshOnOpen => _refreshOnOpen;
  SessionRefreshPolicy get refreshOnMessage => _refreshOnMessage;
  ListRefreshPolicy get refreshOnReturn => _refreshOnReturn;
  ListRefreshPolicy get refreshOnCreate => _refreshOnCreate;
  int get sessionPageSize => _sessionPageSize;
  List<RefreshSchedule> get schedules => _schedules;
  bool get isInitialized => _isInitialized;
  bool get notifyOnAttention => _notifyOnAttention;
  bool get notifyOnCompletion => _notifyOnCompletion;
  bool get notifyOnWatch => _notifyOnWatch;
  bool get notifyOnFailure => _notifyOnFailure;
  bool get trayEnabled => _trayEnabled;
  FabVisibility get fabVisibility => _fabVisibility;
  bool get hideArchivedAndReadOnly => _hideArchivedAndReadOnly;

  // Keybinding Getters
  MessageSubmitAction get enterKeyAction => _enterKeyAction;
  MessageSubmitAction get shiftEnterKeyAction => _shiftEnterKeyAction;
  MessageSubmitAction get ctrlEnterKeyAction => _ctrlEnterKeyAction;
  MessageSubmitAction get ctrlShiftEnterKeyAction => _ctrlShiftEnterKeyAction;
  EscKeyAction get escKeyAction => _escKeyAction;

  // Filter Getters
  FilterElement? get lastFilter => _lastFilter;

  // Bulk Action Getters
  List<BulkActionStep> get lastBulkActions => _lastBulkActions;
  int get lastBulkParallelQueries => _lastBulkParallelQueries;
  int get lastBulkWaitBetweenSeconds => _lastBulkWaitBetweenSeconds;
  int? get lastBulkLimit => _lastBulkLimit;
  int get lastBulkOffset => _lastBulkOffset;
  bool get lastBulkRandomize => _lastBulkRandomize;
  bool get lastBulkStopOnError => _lastBulkStopOnError;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs == null) return;

    _refreshOnOpen = _loadEnum(
      keyRefreshOnOpen,
      SessionRefreshPolicy.values,
      SessionRefreshPolicy.shallow,
    );
    _refreshOnMessage = _loadEnum(
      keyRefreshOnMessage,
      SessionRefreshPolicy.values,
      SessionRefreshPolicy.shallow,
    );
    _refreshOnReturn = _loadEnum(
      keyRefreshOnReturn,
      ListRefreshPolicy.values,
      ListRefreshPolicy.dirty,
    );
    _refreshOnCreate = _loadEnum(
      keyRefreshOnCreate,
      ListRefreshPolicy.values,
      ListRefreshPolicy.quick,
    );
    _sessionPageSize = _prefs!.getInt(_sessionPageSizeKey) ?? 100;
    _notifyOnAttention = _prefs!.getBool(keyNotifyOnAttention) ?? true;
    _notifyOnCompletion = _prefs!.getBool(keyNotifyOnCompletion) ?? true;
    _notifyOnWatch = _prefs!.getBool(keyNotifyOnWatch) ?? true;
    _notifyOnFailure = _prefs!.getBool(keyNotifyOnFailure) ?? true;
    _trayEnabled = _prefs!.getBool(keyTrayEnabled) ?? false;
    _fabVisibility = _loadEnum(
      keyFabVisibility,
      FabVisibility.values,
      FabVisibility.floating,
    );
    _hideArchivedAndReadOnly =
        _prefs!.getBool(keyHideArchivedAndReadOnly) ?? true;

    // Load keybindings
    _enterKeyAction = _loadEnum(
      keyEnterKeyAction,
      MessageSubmitAction.values,
      MessageSubmitAction.addNewLine,
    );
    _shiftEnterKeyAction = _loadEnum(
      keyShiftEnterKeyAction,
      MessageSubmitAction.values,
      MessageSubmitAction.addNewLine,
    );
    _ctrlEnterKeyAction = _loadEnum(
      keyCtrlEnterKeyAction,
      MessageSubmitAction.values,
      MessageSubmitAction.submitsMessage,
    );
    _ctrlShiftEnterKeyAction = _loadEnum(
      keyCtrlShiftEnterKeyAction,
      MessageSubmitAction.values,
      MessageSubmitAction.submitsMessageAndGoesBack,
    );
    _escKeyAction = _loadEnum(
      keyEscKeyAction,
      EscKeyAction.values,
      EscKeyAction.doesNothing,
    );

    _loadSchedules();
    _loadBulkActionConfig();

    // Load last filter
    final lastFilterJson = _prefs!.getString(_lastFilterKey);
    if (lastFilterJson != null) {
      try {
        _lastFilter = FilterElement.fromJson(jsonDecode(lastFilterJson));
      } catch (e) {
        // Could log this error
      }
    }

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
        name: 'Refresh while session is open',
        intervalInMinutes: 5,
        refreshPolicy: ListRefreshPolicy.quick,
      ),
      RefreshSchedule(
        name: 'Full Refresh',
        intervalInMinutes: 60,
        refreshPolicy: ListRefreshPolicy.full,
      ),
      RefreshSchedule(
        name: 'Watched Refresh',
        intervalInMinutes: 5,
        refreshPolicy: ListRefreshPolicy.watched,
      ),
      RefreshSchedule(
        name: 'Quick Refresh',
        intervalInMinutes: 15,
        refreshPolicy: ListRefreshPolicy.quick,
      ),
      RefreshSchedule(
        name: 'Send Pending Messages',
        intervalInMinutes: 5,
        taskType: RefreshTaskType.sendPendingMessages,
        sendMessagesMode: SendMessagesMode.sendAllUntilFailure,
      ),
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

  Future<void> setNotifyOnAttention(bool value) async {
    _notifyOnAttention = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnAttention, value);
  }

  Future<void> setNotifyOnCompletion(bool value) async {
    _notifyOnCompletion = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnCompletion, value);
  }

  Future<void> setNotifyOnWatch(bool value) async {
    _notifyOnWatch = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnWatch, value);
  }

  Future<void> setNotifyOnFailure(bool value) async {
    _notifyOnFailure = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnFailure, value);
  }

  Future<void> setTrayEnabled(bool value) async {
    _trayEnabled = value;
    notifyListeners();
    await _prefs?.setBool(keyTrayEnabled, value);
  }

  Future<void> setFabVisibility(FabVisibility visibility) async {
    _fabVisibility = visibility;
    notifyListeners();
    await _prefs?.setInt(keyFabVisibility, visibility.index);
  }

  Future<void> setHideArchivedAndReadOnly(bool value) async {
    _hideArchivedAndReadOnly = value;
    notifyListeners();
    await _prefs?.setBool(keyHideArchivedAndReadOnly, value);
  }

  // Keybinding Setters
  Future<void> setEnterKeyAction(MessageSubmitAction action) async {
    _enterKeyAction = action;
    notifyListeners();
    await _prefs?.setInt(keyEnterKeyAction, action.index);
  }

  Future<void> setShiftEnterKeyAction(MessageSubmitAction action) async {
    _shiftEnterKeyAction = action;
    notifyListeners();
    await _prefs?.setInt(keyShiftEnterKeyAction, action.index);
  }

  Future<void> setCtrlEnterKeyAction(MessageSubmitAction action) async {
    _ctrlEnterKeyAction = action;
    notifyListeners();
    await _prefs?.setInt(keyCtrlEnterKeyAction, action.index);
  }

  Future<void> setCtrlShiftEnterKeyAction(MessageSubmitAction action) async {
    _ctrlShiftEnterKeyAction = action;
    notifyListeners();
    await _prefs?.setInt(keyCtrlShiftEnterKeyAction, action.index);
  }

  Future<void> setEscKeyAction(EscKeyAction action) async {
    _escKeyAction = action;
    notifyListeners();
    await _prefs?.setInt(keyEscKeyAction, action.index);
  }

  Future<void> setLastFilter(FilterElement? filter) async {
    _lastFilter = filter;
    if (filter == null) {
      await _prefs?.remove(_lastFilterKey);
    } else {
      await _prefs?.setString(_lastFilterKey, jsonEncode(filter.toJson()));
    }
    notifyListeners();
  }

  void _loadBulkActionConfig() {
    final jsonString = _prefs?.getString(_bulkActionConfigKey);
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString);
        if (json['actions'] != null && json['actions'] is List) {
          _lastBulkActions = (json['actions'] as List)
              .map((a) => BulkActionStep.fromJson(a))
              .toList();
        }
        _lastBulkParallelQueries = json['parallelQueries'] ?? 1;
        _lastBulkWaitBetweenSeconds = json['waitBetweenSeconds'] ?? 2;
        _lastBulkLimit = json['limit'];
        _lastBulkOffset = json['offset'] ?? 0;
        _lastBulkRandomize = json['randomize'] ?? false;
        _lastBulkStopOnError = json['stopOnError'] ?? false;
      } catch (e) {
        // Could log this
      }
    }
  }

  Future<void> saveBulkActionConfig({
    required List<BulkActionStep> actions,
    required int parallelQueries,
    required int waitBetweenSeconds,
    required int? limit,
    required int offset,
    required bool randomize,
    required bool stopOnError,
  }) async {
    _lastBulkActions = actions;
    _lastBulkParallelQueries = parallelQueries;
    _lastBulkWaitBetweenSeconds = waitBetweenSeconds;
    _lastBulkLimit = limit;
    _lastBulkOffset = offset;
    _lastBulkRandomize = randomize;
    _lastBulkStopOnError = stopOnError;

    final Map<String, dynamic> config = {
      'actions': actions.map((a) => a.toJson()).toList(),
      'parallelQueries': parallelQueries,
      'waitBetweenSeconds': waitBetweenSeconds,
      'limit': limit,
      'offset': offset,
      'randomize': randomize,
      'stopOnError': stopOnError,
    };

    final jsonString = jsonEncode(config);
    await _prefs?.setString(_bulkActionConfigKey, jsonString);
    notifyListeners();
  }
}
