import 'package:flutter_jules/models/enums.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/services/notification_service.dart';
import 'package:flutter_jules/services/settings_provider.dart';

class SessionComparator {
  final SettingsProvider _settingsProvider;
  final NotificationService _notificationService;

  SessionComparator(this._settingsProvider, this._notificationService);

  String compare(List<Session> oldSessions, List<Session> newSessions) {
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
}
