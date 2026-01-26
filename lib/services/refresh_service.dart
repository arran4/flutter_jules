import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_jules/services/activity_provider.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'settings_provider.dart';
import 'session_provider.dart';
import 'source_provider.dart';
import 'auth_provider.dart';
import 'jules_client.dart';
import 'exceptions.dart';
import '../models/refresh_schedule.dart';
import 'notification_service.dart';
import '../models/enums.dart';
import 'session_comparator.dart';
import 'timer_service.dart';

class RefreshService extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final SessionProvider _sessionProvider;
  final SourceProvider _sourceProvider;
  final AuthProvider _authProvider;
  final NotificationService _notificationService;
  final MessageQueueProvider _messageQueueProvider;
  final ActivityProvider _activityProvider;
  final TimerService _timerService;
  final SessionComparator _sessionComparator;

  RefreshService(
    this._settingsProvider,
    this._sessionProvider,
    this._sourceProvider,
    this._authProvider,
    this._notificationService,
    this._messageQueueProvider,
    this._activityProvider,
    this._timerService, {
    @visibleForTesting SessionComparator? sessionComparator,
  }) : _sessionComparator =
           sessionComparator ??
           SessionComparator(_settingsProvider, _notificationService) {
    _timerService.addListener(_onTick);
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final now = DateTime.now();
    final schedules = List<RefreshSchedule>.from(_settingsProvider.schedules);
    for (final schedule in schedules) {
      if (schedule.isEnabled) {
        if (schedule.lastRun == null ||
            now.difference(schedule.lastRun!).inMinutes >=
                schedule.intervalInMinutes) {
          schedule.lastRun = now;
          _settingsProvider.updateSchedule(schedule);
          _executeSchedule(schedule);
        }
      }
    }
  }

  void notifyManualRun(
    RefreshTaskType type, {
    ListRefreshPolicy? refreshPolicy,
    SendMessagesMode? sendMessagesMode,
  }) {
    final now = DateTime.now();
    // Create a copy of the list to avoid concurrent modification issues if updateSchedule modifies the list
    final schedules = List<RefreshSchedule>.from(_settingsProvider.schedules);
    for (final schedule in schedules) {
      if (!schedule.isEnabled) continue;
      if (schedule.taskType != type) continue;

      bool matches = false;
      if (type == RefreshTaskType.refresh) {
        if (refreshPolicy == ListRefreshPolicy.full) {
          // Full satisfies Full and Quick
          if (schedule.refreshPolicy == ListRefreshPolicy.full ||
              schedule.refreshPolicy == ListRefreshPolicy.quick) {
            matches = true;
          }
        } else if (refreshPolicy == schedule.refreshPolicy) {
          matches = true;
        }
      } else if (type == RefreshTaskType.sendPendingMessages) {
        if (sendMessagesMode == SendMessagesMode.sendAllUntilFailure) {
          if (schedule.sendMessagesMode ==
                  SendMessagesMode.sendAllUntilFailure ||
              schedule.sendMessagesMode == SendMessagesMode.sendOne) {
            matches = true;
          }
        } else if (sendMessagesMode == schedule.sendMessagesMode) {
          matches = true;
        }
      }

      if (matches) {
        schedule.lastRun = now;
        _settingsProvider.updateSchedule(schedule);
      }
    }
  }

  void _executeSchedule(RefreshSchedule schedule) async {
    if (_settingsProvider.notifyOnRefreshStart) {
      _notificationService.showNotification(
        'Refresh Started',
        'Executing schedule: ${schedule.name}',
      );
    }
    final client = _authProvider.client;
    try {
      String summary = '';
      switch (schedule.taskType) {
        case RefreshTaskType.refresh:
          summary = await _executeRefresh(schedule, client);
          break;
        case RefreshTaskType.sendPendingMessages:
          await _executeSendPendingMessages(schedule, client);
          summary = 'Sent pending messages.';
          break;
      }
      if (_settingsProvider.notifyOnRefreshComplete) {
        final actions = <NotificationAction>[];
        if (summary != 'No new updates.') {
          actions.add(NotificationAction.showNew);
        }
        _notificationService.showNotification(
          'Refresh Complete',
          'Finished executing schedule: ${schedule.name}. $summary',
          actions: actions,
        );
      }
    } on InvalidTokenException catch (_) {
      _notificationService.showNotification(
        'Authentication Error',
        'Invalid API token provided. Please check your settings.',
        payload: 'auth_error',
      );
    } catch (e) {
      if (_settingsProvider.notifyOnErrors) {
        _notificationService.showNotification(
          'Refresh Error',
          'Error executing schedule: ${schedule.name}: $e',
        );
      }
    }
  }

  Future<String> _executeRefresh(
    RefreshSchedule schedule,
    JulesClient client,
  ) async {
    final oldSessions = _sessionProvider.items.map((e) => e.data).toList();
    switch (schedule.refreshPolicy) {
      case ListRefreshPolicy.full:
        await _sessionProvider.fetchSessions(client, force: true);
        await _sourceProvider.fetchSources(client, force: true);
        break;
      case ListRefreshPolicy.quick:
        await _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.watched:
        if (_authProvider.token != null) {
          await _sessionProvider.refreshWatchedSessions(
            client,
            authToken: _authProvider.token!,
          );
        }
        break;
      case ListRefreshPolicy.dirty:
        if (_authProvider.token != null) {
          await _sessionProvider.refreshDirtySessions(
            client,
            authToken: _authProvider.token!,
          );
        }
        break;
      case ListRefreshPolicy.none:
        return 'No changes';
      default:
        return 'No changes';
    }
    final newSessions = _sessionProvider.items.map((e) => e.data).toList();
    return _sessionComparator.compare(oldSessions, newSessions);
  }

  ({RefreshSchedule schedule, DateTime time})? getNextScheduledRefresh() {
    final now = DateTime.now();
    final schedules = _settingsProvider.schedules
        .where((s) => s.isEnabled)
        .toList();

    if (schedules.isEmpty) return null;

    RefreshSchedule? bestSchedule;
    DateTime? bestTime;

    for (final schedule in schedules) {
      DateTime nextTime;
      if (schedule.lastRun == null) {
        nextTime = now;
      } else {
        nextTime = schedule.lastRun!.add(
          Duration(minutes: schedule.intervalInMinutes),
        );
      }

      if (bestTime == null || nextTime.isBefore(bestTime)) {
        bestTime = nextTime;
        bestSchedule = schedule;
      }
    }

    if (bestSchedule != null && bestTime != null) {
      return (schedule: bestSchedule, time: bestTime);
    }
    return null;
  }

  Future<void> _executeSendPendingMessages(
    RefreshSchedule schedule,
    JulesClient client,
  ) async {
    if (_messageQueueProvider.queue.isEmpty) {
      _activityProvider.addLog(
        'No pending messages to send for schedule ${schedule.name}',
      );
      return;
    }

    switch (schedule.sendMessagesMode) {
      case SendMessagesMode.sendOne:
        try {
          await _messageQueueProvider.sendQueue(client, limit: 1);
          _activityProvider.addLog(
            'Successfully sent one message for ${schedule.name}',
          );
        } catch (e) {
          _activityProvider.addLog(
            'Failed to send message for ${schedule.name}: $e',
          );
        }
        break;
      case SendMessagesMode.sendAllUntilFailure:
        try {
          await _messageQueueProvider.sendQueue(client);
          _activityProvider.addLog(
            'Successfully sent all pending messages for ${schedule.name}',
          );
        } catch (e) {
          _activityProvider.addLog(
            'Failed to send all pending messages for ${schedule.name}: $e',
          );
        }
        break;
      default:
        return;
    }
  }
}
