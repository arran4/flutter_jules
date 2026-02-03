import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/themes.dart';
import '../models/bulk_action.dart';
import '../models/refresh_schedule.dart';
import '../models/scheduler_preset.dart';
import '../models/github_exclusion.dart';
import '../models/unread_rule.dart';
import '../models/enums.dart';
import '../models/filter_element.dart';
import '../models/source_group.dart';

class SettingsProvider extends ChangeNotifier {
  static const String keyRefreshOnAppStart = 'refresh_on_app_start';
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
  static const String keyNotifyOnRefreshStart = 'notify_on_refresh_start';
  static const String keyNotifyOnRefreshComplete = 'notify_on_refresh_complete';
  static const String keyNotifyOnErrors = 'notify_on_errors';
  static const String _bulkActionConfigKey = 'bulk_action_config';
  static const String _lastFilterKey = 'last_filter';
  static const String keyTrayEnabled = 'tray_enabled';
  static const String keyHideToTray = 'hide_to_tray';
  static const String keyFabVisibility = 'fab_visibility';
  static const String keyHideArchivedAndReadOnly =
      'hide_archived_and_read_only';
  static const String _githubExclusionsKey = 'github_exclusions';
  static const String _sourceGroupsKey = 'source_groups';
  static const String keyUseCorpJulesUrl = 'use_corp_jules_url';
  static const String keyThemeType = 'theme_type';
  static const String keyThemeMode = 'theme_mode';
  static const String keyEnableNotificationDebounce =
      'enable_notification_debounce';
  static const String keyNotificationDebounceDuration =
      'notification_debounce_duration';
  static const String keyAppBarRefreshActions = 'app_bar_refresh_actions';
  static const String keyUnreadRules = 'unread_rules';

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
  int _lastBulkWaitBetweenMilliseconds = 2000;
  DelayUnit _lastBulkWaitBetweenUnit = DelayUnit.ms;
  int? _lastBulkLimit;
  int _lastBulkOffset = 0;
  bool _lastBulkRandomize = false;
  bool _lastBulkStopOnError = false;

  ListRefreshPolicy _refreshOnAppStart = ListRefreshPolicy.quick;
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
  bool _notifyOnRefreshStart = false;
  bool _notifyOnRefreshComplete = false;
  bool _notifyOnErrors = false;
  bool _trayEnabled = false;
  bool _hideToTray = true;
  FabVisibility _fabVisibility = FabVisibility.floating;
  bool _hideArchivedAndReadOnly = true;
  List<GithubExclusion> _githubExclusions = [];
  List<SourceGroup> _sourceGroups = [];
  bool _useCorpJulesUrl = false;
  JulesThemeType _themeType = JulesThemeType.blue;
  ThemeMode _themeMode = ThemeMode.system;
  bool _enableNotificationDebounce = false;
  int _notificationDebounceDuration = 5000;
  Set<RefreshButtonAction> _appBarRefreshActions = {
    RefreshButtonAction.refresh,
  };
  List<UnreadRule> _unreadRules = [];

  // Keybinding Actions
  MessageSubmitAction _enterKeyAction = MessageSubmitAction.addNewLine;
  MessageSubmitAction _shiftEnterKeyAction = MessageSubmitAction.addNewLine;
  MessageSubmitAction _ctrlEnterKeyAction = MessageSubmitAction.submitsMessage;
  MessageSubmitAction _ctrlShiftEnterKeyAction =
      MessageSubmitAction.submitsMessageAndGoesBack;
  EscKeyAction _escKeyAction = EscKeyAction.doesNothing;

  SharedPreferences? _prefs;

  ListRefreshPolicy get refreshOnAppStart => _refreshOnAppStart;
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
  bool get notifyOnRefreshStart => _notifyOnRefreshStart;
  bool get notifyOnRefreshComplete => _notifyOnRefreshComplete;
  bool get notifyOnErrors => _notifyOnErrors;
  bool get trayEnabled => _trayEnabled;
  bool get hideToTray => _hideToTray;
  FabVisibility get fabVisibility => _fabVisibility;
  bool get hideArchivedAndReadOnly => _hideArchivedAndReadOnly;
  List<GithubExclusion> get githubExclusions => _githubExclusions;
  List<SourceGroup> get sourceGroups => _sourceGroups;
  bool get useCorpJulesUrl => _useCorpJulesUrl;
  JulesThemeType get themeType => _themeType;
  ThemeMode get themeMode => _themeMode;
  bool get enableNotificationDebounce => _enableNotificationDebounce;
  int get notificationDebounceDuration => _notificationDebounceDuration;
  Set<RefreshButtonAction> get appBarRefreshActions => _appBarRefreshActions;
  List<UnreadRule> get unreadRules => _unreadRules;

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
  int get lastBulkWaitBetweenMilliseconds => _lastBulkWaitBetweenMilliseconds;
  DelayUnit get lastBulkWaitBetweenUnit => _lastBulkWaitBetweenUnit;
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

    _refreshOnAppStart = _loadEnum(
      keyRefreshOnAppStart,
      ListRefreshPolicy.values,
      ListRefreshPolicy.quick,
    );
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
    _notifyOnRefreshStart = _prefs!.getBool(keyNotifyOnRefreshStart) ?? false;
    _notifyOnRefreshComplete =
        _prefs!.getBool(keyNotifyOnRefreshComplete) ?? false;
    _notifyOnErrors = _prefs!.getBool(keyNotifyOnErrors) ?? false;
    _trayEnabled = _prefs!.getBool(keyTrayEnabled) ?? false;
    _hideToTray = _prefs!.getBool(keyHideToTray) ?? true;
    _fabVisibility = _loadEnum(
      keyFabVisibility,
      FabVisibility.values,
      FabVisibility.floating,
    );
    _hideArchivedAndReadOnly =
        _prefs!.getBool(keyHideArchivedAndReadOnly) ?? true;
    _useCorpJulesUrl = _prefs!.getBool(keyUseCorpJulesUrl) ?? false;

    _themeType = _loadEnum(
      keyThemeType,
      JulesThemeType.values,
      JulesThemeType.blue,
    );
    _themeMode = _loadEnum(keyThemeMode, ThemeMode.values, ThemeMode.system);
    _enableNotificationDebounce =
        _prefs!.getBool(keyEnableNotificationDebounce) ?? false;
    _notificationDebounceDuration =
        _prefs!.getInt(keyNotificationDebounceDuration) ?? 5000;
    _loadUnreadRules();

    if (_prefs!.containsKey(keyAppBarRefreshActions)) {
      final refreshActionsList =
          _prefs!.getStringList(keyAppBarRefreshActions) ?? [];
      _appBarRefreshActions = refreshActionsList
          .map(
            (e) => RefreshButtonAction.values.firstWhere(
              (a) => a.name == e,
              orElse: () => RefreshButtonAction.refresh,
            ),
          )
          .toSet();
    }

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
    _loadSchedules();
    _loadBulkActionConfig();
    _loadGithubExclusions();
    _loadSourceGroups();

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
    return SchedulerPreset.presets.first.schedulesFactory();
  }

  Future<void> applySchedulerPreset(SchedulerPreset preset) async {
    _schedules = preset.schedulesFactory();
    await _saveSchedules();
    notifyListeners();
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

  Future<void> setRefreshOnAppStart(ListRefreshPolicy policy) async {
    _refreshOnAppStart = policy;
    notifyListeners();
    await _prefs?.setInt(keyRefreshOnAppStart, policy.index);
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

  Future<void> setNotifyOnRefreshStart(bool value) async {
    _notifyOnRefreshStart = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnRefreshStart, value);
  }

  Future<void> setNotifyOnRefreshComplete(bool value) async {
    _notifyOnRefreshComplete = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnRefreshComplete, value);
  }

  Future<void> setNotifyOnErrors(bool value) async {
    _notifyOnErrors = value;
    notifyListeners();
    await _prefs?.setBool(keyNotifyOnErrors, value);
  }

  Future<void> setTrayEnabled(bool value) async {
    _trayEnabled = value;
    notifyListeners();
    await _prefs?.setBool(keyTrayEnabled, value);
  }

  Future<void> setHideToTray(bool value) async {
    _hideToTray = value;
    notifyListeners();
    await _prefs?.setBool(keyHideToTray, value);
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

  Future<void> setUseCorpJulesUrl(bool value) async {
    _useCorpJulesUrl = value;
    notifyListeners();
    await _prefs?.setBool(keyUseCorpJulesUrl, value);
  }

  Future<void> setThemeType(JulesThemeType value) async {
    _themeType = value;
    notifyListeners();
    await _prefs?.setInt(keyThemeType, value.index);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    await _prefs?.setInt(keyThemeMode, value.index);
  }

  Future<void> setEnableNotificationDebounce(bool value) async {
    _enableNotificationDebounce = value;
    notifyListeners();
    await _prefs?.setBool(keyEnableNotificationDebounce, value);
  }

  Future<void> setNotificationDebounceDuration(int value) async {
    _notificationDebounceDuration = value;
    notifyListeners();
    await _prefs?.setInt(keyNotificationDebounceDuration, value);
  }

  Future<void> setAppBarRefreshActions(Set<RefreshButtonAction> actions) async {
    _appBarRefreshActions = actions;
    notifyListeners();
    await _prefs?.setStringList(
      keyAppBarRefreshActions,
      actions.map((e) => e.name).toList(),
    );
  }

  void _loadUnreadRules() {
    final jsonString = _prefs?.getString(keyUnreadRules);
    if (jsonString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        _unreadRules =
            decodedList.map((json) => UnreadRule.fromJson(json)).toList();
      } catch (e) {
        _unreadRules = _defaultUnreadRules();
      }
    } else {
      _unreadRules = _defaultUnreadRules();
    }
  }

  List<UnreadRule> _defaultUnreadRules() {
    return [
      UnreadRule(
        id: 'default-session-state',
        type: RuleType.sessionState,
        action: RuleAction.markUnread,
        enabled: true,
      ),
      UnreadRule(
        id: 'default-step-change',
        type: RuleType.stepChange,
        action: RuleAction.markUnread,
        enabled: true,
      ),
      UnreadRule(
        id: 'default-pr-draft-open',
        type: RuleType.prStatus,
        fromValue: 'Draft',
        toValue: 'Open',
        action: RuleAction.markUnread,
        enabled: true,
      ),
      UnreadRule(
        id: 'default-pr-open-closed',
        type: RuleType.prStatus,
        fromValue: 'Open',
        toValue: 'Closed',
        action: RuleAction.markUnread,
        enabled: true,
      ),
      UnreadRule(
        id: 'default-ci-failure',
        type: RuleType.ciStatus,
        toValue: 'Failure',
        action: RuleAction.markUnread,
        enabled: true,
      ),
    ];
  }

  Future<void> _saveUnreadRules() async {
    final jsonString = jsonEncode(_unreadRules.map((r) => r.toJson()).toList());
    await _prefs?.setString(keyUnreadRules, jsonString);
  }

  Future<void> addUnreadRule(UnreadRule rule) async {
    _unreadRules.add(rule);
    await _saveUnreadRules();
    notifyListeners();
  }

  Future<void> updateUnreadRule(UnreadRule rule) async {
    final index = _unreadRules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _unreadRules[index] = rule;
      await _saveUnreadRules();
      notifyListeners();
    }
  }

  Future<void> deleteUnreadRule(String id) async {
    _unreadRules.removeWhere((r) => r.id == id);
    await _saveUnreadRules();
    notifyListeners();
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

        // Load new millisecond value, fall back to old second value
        if (json['waitBetweenMilliseconds'] != null) {
          _lastBulkWaitBetweenMilliseconds = json['waitBetweenMilliseconds'];
        } else if (json['waitBetweenSeconds'] != null) {
          _lastBulkWaitBetweenMilliseconds =
              (json['waitBetweenSeconds'] as int) * 1000;
        } else {
          _lastBulkWaitBetweenMilliseconds = 2000;
        }

        if (json['waitBetweenUnit'] != null) {
          _lastBulkWaitBetweenUnit =
              DelayUnit.values[json['waitBetweenUnit'] as int];
        } else {
          _lastBulkWaitBetweenUnit = DelayUnit.ms;
        }

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
    required int waitBetweenMilliseconds,
    required DelayUnit waitBetweenUnit,
    required int? limit,
    required int offset,
    required bool randomize,
    required bool stopOnError,
  }) async {
    _lastBulkActions = actions;
    _lastBulkParallelQueries = parallelQueries;
    _lastBulkWaitBetweenMilliseconds = waitBetweenMilliseconds;
    _lastBulkWaitBetweenUnit = waitBetweenUnit;
    _lastBulkLimit = limit;
    _lastBulkOffset = offset;
    _lastBulkRandomize = randomize;
    _lastBulkStopOnError = stopOnError;

    final Map<String, dynamic> config = {
      'actions': actions.map((a) => a.toJson()).toList(),
      'parallelQueries': parallelQueries,
      'waitBetweenMilliseconds': waitBetweenMilliseconds,
      'waitBetweenUnit': waitBetweenUnit.index,
      'limit': limit,
      'offset': offset,
      'randomize': randomize,
      'stopOnError': stopOnError,
    };

    final jsonString = jsonEncode(config);
    await _prefs?.setString(_bulkActionConfigKey, jsonString);
    notifyListeners();
  }

  void _loadGithubExclusions() {
    final jsonString = _prefs?.getString(_githubExclusionsKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        _githubExclusions =
            decodedList.map((json) => GithubExclusion.fromJson(json)).toList();
      } catch (e) {
        _githubExclusions = [];
      }
    } else {
      _githubExclusions = [];
    }
  }

  Future<void> _saveGithubExclusions() async {
    final jsonString = jsonEncode(
      _githubExclusions.map((e) => e.toJson()).toList(),
    );
    await _prefs?.setString(_githubExclusionsKey, jsonString);
  }

  Future<void> addGithubExclusion(GithubExclusion exclusion) async {
    // Avoid duplicates
    if (_githubExclusions.any(
      (e) => e.type == exclusion.type && e.value == exclusion.value,
    )) {
      return;
    }
    _githubExclusions.add(exclusion);
    await _saveGithubExclusions();
    notifyListeners();
  }

  Future<void> removeGithubExclusion(
    String value,
    GithubExclusionType type,
  ) async {
    _githubExclusions.removeWhere((e) => e.value == value && e.type == type);
    await _saveGithubExclusions();
    notifyListeners();
  }

  bool isExcluded(String userOrgRepo) {
    if (userOrgRepo.isEmpty) return false;

    final parts = userOrgRepo.split('/');

    // Check for PR exclusion
    if (parts.length == 3) {
      if (_githubExclusions.any(
        (e) =>
            e.type == GithubExclusionType.pullRequest && e.value == userOrgRepo,
      )) {
        return true;
      }
    }

    // Check for Repo exclusion
    if (parts.length >= 2) {
      final repo = '${parts[0]}/${parts[1]}';
      if (_githubExclusions.any(
        (e) => e.type == GithubExclusionType.repo && e.value == repo,
      )) {
        return true;
      }
    }

    // Check for Org exclusion
    if (parts.isNotEmpty) {
      final org = parts[0];
      if (_githubExclusions.any(
        (e) => e.type == GithubExclusionType.org && e.value == org,
      )) {
        return true;
      }
    }

    return false;
  }

  void _loadSourceGroups() {
    final jsonString = _prefs?.getString(_sourceGroupsKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(jsonString);
        _sourceGroups =
            decodedList.map((json) => SourceGroup.fromJson(json)).toList();
      } catch (e) {
        _sourceGroups = [];
      }
    } else {
      _sourceGroups = [];
    }
  }

  Future<void> _saveSourceGroups() async {
    final jsonString = jsonEncode(
      _sourceGroups.map((g) => g.toJson()).toList(),
    );
    await _prefs?.setString(_sourceGroupsKey, jsonString);
  }

  Future<void> addSourceGroup(SourceGroup group) async {
    _sourceGroups.add(group);
    await _saveSourceGroups();
    notifyListeners();
  }

  Future<void> updateSourceGroup(SourceGroup group) async {
    final index = _sourceGroups.indexWhere((g) => g.name == group.name);
    if (index != -1) {
      _sourceGroups[index] = group;
      await _saveSourceGroups();
      notifyListeners();
    }
  }

  Future<void> deleteSourceGroup(String groupName) async {
    _sourceGroups.removeWhere((g) => g.name == groupName);
    await _saveSourceGroups();
    notifyListeners();
  }
}
