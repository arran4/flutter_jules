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
import '../models/session.dart';
import '../models/enums.dart';

class RefreshService extends ChangeNotifier {
  final SettingsProvider _settingsProvider;
  final SessionProvider _sessionProvider;
  final SourceProvider _sourceProvider;
  final AuthProvider _authProvider;
  final NotificationService _notificationService;
  final MessageQueueProvider _messageQueueProvider;
  final ActivityProvider _activityProvider;

  final Map<String, Timer> _timers = {};

  RefreshService(
    this._settingsProvider,
    this._sessionProvider,
    this._sourceProvider,
    this._authProvider,
    this._notificationService,
    this._messageQueueProvider,
    this._activityProvider,
  ) {
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
      (timer) => _executeSchedule(schedule),
    );
  }

  void _executeSchedule(RefreshSchedule schedule) async {
    if (_settingsProvider.notifyOnRefreshStart) {
      _notificationService.showNotification(
        'Refresh Started',
        'Executing schedule: ${schedule.name}',
      );
    }
    schedule.lastRun = DateTime.now();
    _settingsProvider.updateSchedule(schedule);
    final client = JulesClient(accessToken: _authProvider.token);
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
      RefreshSchedule schedule, JulesClient client) async {
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
        await _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.dirty:
        await _sessionProvider.fetchSessions(client);
        break;
      case ListRefreshPolicy.none:
        return 'No changes';
      default:
        return 'No changes';
    }
    final newSessions = _sessionProvider.items.map((e) => e.data).toList();
    return compareSessions(oldSessions, newSessions);
  }

  Future<void> _executeSendPendingMessages(
      RefreshSchedule schedule, JulesClient client) async {
    if (_messageQueueProvider.queue.isEmpty) {
      _activityProvider
          .addLog('No pending messages to send for schedule ${schedule.name}');
      return;
    }

    switch (schedule.sendMessagesMode) {
      case SendMessagesMode.sendOne:
        try {
          await _messageQueueProvider.sendQueue(client, limit: 1);
          _activityProvider
              .addLog('Successfully sent one message for ${schedule.name}');
        } catch (e) {
          _activityProvider
              .addLog('Failed to send message for ${schedule.name}: $e');
        }
        break;
      case SendMessagesMode.sendAllUntilFailure:
        try {
          await _messageQueueProvider.sendQueue(client);
          _activityProvider.addLog(
              'Successfully sent all pending messages for ${schedule.name}');
        } catch (e) {
          _activityProvider.addLog(
              'Failed to send all pending messages for ${schedule.name}: $e');
        }
        break;
      default:
        return;
    }
  }

  @visibleForTesting
  String compareSessions(List<Session> oldSessions, List<Session> newSessions) {
    final oldSessionMap = {for (var s in oldSessions) s.name: s};
    int newUnread = 0;
    int newSessionsCount = 0;
    int newWaitingApproval = 0;
    int newWaitingFeedback = 0;
    int prsWaiting = 0;

    for (final newSession in newSessions) {
      final oldSession = oldSessionMap[newSession.name];
      final isNew = oldSession == null;
      if (isNew) {
        newSessionsCount++;
      }
      /* if (newSession.isUnread ?? false) {
        newUnread++;
      } */
      if (newSession.state == SessionState.AWAITING_PLAN_APPROVAL) {
        newWaitingApproval++;
      }
      if (newSession.state == SessionState.AWAITING_USER_FEEDBACK) {
        newWaitingFeedback++;
      }
      // Assuming some logic to determine if a session is a PR
      if (newSession.outputs?.any((o) => o.pullRequest != null) ?? false) {
        prsWaiting++;
      }

      final stateChanged = !isNew && oldSession.state != newSession.state;

      if (isNew || stateChanged) {
        if (_settingsProvider.notifyOnAttention &&
            newSession.state == SessionState.AWAITING_PLAN_APPROVAL) {
          _notificationService.showNotification(
            'Task requires your attention',
            newSession.title ?? 'Untitled Task',
            payload: newSession.name,
          );
        } else if (_settingsProvider.notifyOnCompletion &&
            newSession.state == SessionState.COMPLETED) {
          _notificationService.showNotification(
            'Task completed',
            newSession.title ?? 'Untitled Task',
            payload: newSession.name,
          );
        } else if (_settingsProvider.notifyOnFailure &&
            newSession.state == SessionState.FAILED) {
          _notificationService.showNotification(
            'Task failed',
            newSession.title ?? 'Untitled Task',
            payload: newSession.name,
          );
        } else if (_settingsProvider.notifyOnWatch &&
            (newSession.title?.toLowerCase().contains('watched') ?? false)) {
          _notificationService.showNotification(
            isNew ? 'New task created' : 'Watched task updated',
            newSession.title ?? 'Untitled Task',
            payload: newSession.name,
          );
        }
      }
    }
    final summaryParts = <String>[];
    if (newUnread > 0) summaryParts.add('new unread: $newUnread');
    if (newSessionsCount > 0) {
      summaryParts.add('new sessions: $newSessionsCount');
    }
    if (newWaitingApproval > 0) {
      summaryParts.add('waiting approval: $newWaitingApproval');
    }
    if (newWaitingFeedback > 0) {
      summaryParts.add('waiting feedback: $newWaitingFeedback');
    }
    if (prsWaiting > 0) summaryParts.add('PRs waiting: $prsWaiting');

    if (summaryParts.isEmpty) {
      return 'No new updates.';
    }

    String summary = summaryParts.join(', ');
    summary = summary[0].toUpperCase() + summary.substring(1);
    return '${summary[0].toUpperCase()}${summary.substring(1)}.';
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
