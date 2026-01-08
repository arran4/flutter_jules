import 'dart:async';
import 'package:flutter/material.dart';
import 'settings_provider.dart';
import 'session_provider.dart';
import 'source_provider.dart';
import 'auth_provider.dart';
import 'jules_client.dart';
import '../models/refresh_schedule.dart';

class RefreshService extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final SessionProvider _sessionProvider;
  final SourceProvider _sourceProvider;
  final AuthProvider _authProvider;
  final Map<String, Timer> _timers = {};

  RefreshService(this._settingsProvider, this._sessionProvider,
      this._sourceProvider, this._authProvider) {
    _settingsProvider.addListener(_onSettingsChanged);
    _initializeTimers();
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    _cancelAllTimers();
    super.dispose();
  }

  void _onSettingsChanged() {
    _cancelAllTimers();
    _initializeTimers();
  }

  void _initializeTimers() {
    for (final schedule in _settingsProvider.schedules) {
      if (schedule.isEnabled) {
        _startTimer(schedule);
      }
    }
  }

  void _startTimer(RefreshSchedule schedule) {
    _timers[schedule.id] = Timer.periodic(
      Duration(minutes: schedule.intervalInMinutes),
      (timer) => _executeRefresh(schedule),
    );
  }

  void _executeRefresh(RefreshSchedule schedule) {

    final client = JulesClient(accessToken: _authProvider.token);
    switch (schedule.refreshPolicy) {
      case ListRefreshPolicy.full:
        _sessionProvider.fetchSessions(client, force: true);
        _sourceProvider.fetchSources(client, force: true);
        break;
      case ListRefreshPolicy.quick:
        _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.watched:
        _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.dirty:
        _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.none:
        break;
    }
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
