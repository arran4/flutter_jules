import 'dart:async';
import 'package:flutter/foundation.dart';
import 'message_queue_provider.dart';
import '../models.dart';

class SchedulingService {
  final MessageQueueProvider _messageQueueProvider;
  Timer? _timer;

  SchedulingService(this._messageQueueProvider);

  void start() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkScheduledSessions();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  void _checkScheduledSessions() {
    final now = DateTime.now();
    final scheduledSessions = _messageQueueProvider.queue.where((m) {
      if (m.type != QueuedMessageType.sessionCreation) return false;
      final session = Session.fromJson(m.metadata!);
      return session.state == SessionState.SCHEDULED &&
          session.scheduledTime != null;
    }).toList();

    for (final message in scheduledSessions) {
      final session = Session.fromJson(message.metadata!);
      final scheduledTime = DateTime.parse(session.scheduledTime!);
      if (now.isAfter(scheduledTime)) {
        // It's time to run this session
        final updatedSession = session.copyWith(
          state: SessionState.QUEUED,
          scheduledTime: null,
        );
        _messageQueueProvider.updateCreateSessionRequest(
          message.id,
          updatedSession,
          isDraft: false, // No longer a draft, it's ready to be sent
        );

        // If it's a repeating task, create a new scheduled session
        if (session.isRepeating == true &&
            session.repetitionSchedule != null) {
          final nextScheduledTime =
              _calculateNextScheduledTime(scheduledTime, session.repetitionSchedule!);
          final newSession = session.copyWith(
            scheduledTime: nextScheduledTime.toIso8601String(),
          );
          _messageQueueProvider.addCreateSessionRequest(newSession,
              isDraft: true);
        }
      }
    }
  }

  DateTime _calculateNextScheduledTime(
      DateTime previous, String repetitionSchedule) {
    switch (repetitionSchedule) {
      case 'Daily':
        return previous.add(const Duration(days: 1));
      case 'Weekly':
        return previous.add(const Duration(days: 7));
      case 'Monthly':
        var day = previous.day;
        var month = previous.month + 1;
        var year = previous.year;
        if (month > 12) {
          month = 1;
          year++;
        }
        // Let the DateTime constructor handle cases where the day is out of bounds for the month.
        // For example, if the day is 31 and the next month is April, it will correctly create a date in May.
        return DateTime(year, month, day);
      default:
        return previous.add(const Duration(days: 1));
    }
  }
}
