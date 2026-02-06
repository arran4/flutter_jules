import 'refresh_schedule.dart';
import 'enums.dart';

class SchedulerPreset {
  final String name;
  final String description;
  final List<RefreshSchedule> Function() schedulesFactory;

  const SchedulerPreset({
    required this.name,
    required this.description,
    required this.schedulesFactory,
  });

  static List<SchedulerPreset> get presets => [
        const SchedulerPreset(
          name: 'Standard',
          description: 'Default balanced configuration for regular usage.',
          schedulesFactory: _createStandardSchedules,
        ),
        const SchedulerPreset(
          name: 'Battery Saver',
          description: 'Reduces refresh frequency to save power.',
          schedulesFactory: _createBatterySaverSchedules,
        ),
        const SchedulerPreset(
          name: 'Hourly',
          description: 'Refreshes data every hour.',
          schedulesFactory: _createHourlySchedules,
        ),
        const SchedulerPreset(
          name: 'Daily',
          description: 'Refreshes data only once a day.',
          schedulesFactory: _createDailySchedules,
        ),
        const SchedulerPreset(
          name: 'Aggressive',
          description: 'Very frequent updates for heavy usage.',
          schedulesFactory: _createAggressiveSchedules,
        ),
        const SchedulerPreset(
          name: 'Never (Manual Only)',
          description:
              'No automatic data refresh. Only sends pending messages.',
          schedulesFactory: _createManualSchedules,
        ),
      ];

  static List<RefreshSchedule> _createStandardSchedules() {
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

  static List<RefreshSchedule> _createBatterySaverSchedules() {
    return [
      RefreshSchedule(
        name: 'Full Refresh',
        intervalInMinutes: 240, // 4 hours
        refreshPolicy: ListRefreshPolicy.full,
      ),
      RefreshSchedule(
        name: 'Watched Refresh',
        intervalInMinutes: 15,
        refreshPolicy: ListRefreshPolicy.watched,
      ),
      RefreshSchedule(
        name: 'Quick Refresh',
        intervalInMinutes: 60,
        refreshPolicy: ListRefreshPolicy.quick,
      ),
      RefreshSchedule(
        name: 'Send Pending Messages',
        intervalInMinutes: 15,
        taskType: RefreshTaskType.sendPendingMessages,
        sendMessagesMode: SendMessagesMode.sendAllUntilFailure,
      ),
    ];
  }

  static List<RefreshSchedule> _createDailySchedules() {
    return [
      RefreshSchedule(
        name: 'Daily Full Refresh',
        intervalInMinutes: 1440, // 24 hours
        refreshPolicy: ListRefreshPolicy.full,
      ),
      RefreshSchedule(
        name: 'Send Pending Messages',
        intervalInMinutes: 15,
        taskType: RefreshTaskType.sendPendingMessages,
        sendMessagesMode: SendMessagesMode.sendAllUntilFailure,
      ),
    ];
  }

  static List<RefreshSchedule> _createManualSchedules() {
    return [
      RefreshSchedule(
        name: 'Send Pending Messages',
        intervalInMinutes: 5,
        taskType: RefreshTaskType.sendPendingMessages,
        sendMessagesMode: SendMessagesMode.sendAllUntilFailure,
      ),
    ];
  }

  static List<RefreshSchedule> _createHourlySchedules() {
    return [
      RefreshSchedule(
        name: 'Full Refresh',
        intervalInMinutes: 60,
        refreshPolicy: ListRefreshPolicy.full,
      ),
      RefreshSchedule(
        name: 'Watched Refresh',
        intervalInMinutes: 10,
        refreshPolicy: ListRefreshPolicy.watched,
      ),
      RefreshSchedule(
        name: 'Quick Refresh',
        intervalInMinutes: 30,
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

  static List<RefreshSchedule> _createAggressiveSchedules() {
    return [
      RefreshSchedule(
        name: 'Full Refresh',
        intervalInMinutes: 15,
        refreshPolicy: ListRefreshPolicy.full,
      ),
      RefreshSchedule(
        name: 'Watched Refresh',
        intervalInMinutes: 2,
        refreshPolicy: ListRefreshPolicy.watched,
      ),
      RefreshSchedule(
        name: 'Quick Refresh',
        intervalInMinutes: 5,
        refreshPolicy: ListRefreshPolicy.quick,
      ),
      RefreshSchedule(
        name: 'Send Pending Messages',
        intervalInMinutes: 1,
        taskType: RefreshTaskType.sendPendingMessages,
        sendMessagesMode: SendMessagesMode.sendAllUntilFailure,
      ),
    ];
  }
}
