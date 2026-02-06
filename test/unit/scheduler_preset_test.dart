import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/scheduler_preset.dart';
import 'package:flutter_jules/models/refresh_schedule.dart';
import 'package:flutter_jules/models/enums.dart';

void main() {
  group('SchedulerPreset', () {
    test('Standard preset has correct schedules', () {
      final preset =
          SchedulerPreset.presets.firstWhere((p) => p.name == 'Standard');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 5);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 5 &&
              s.refreshPolicy == ListRefreshPolicy.quick),
          isTrue); // On open (name not checked by logic but by human)
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 60 &&
              s.refreshPolicy == ListRefreshPolicy.full),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 5 &&
              s.refreshPolicy == ListRefreshPolicy.watched),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 15 &&
              s.refreshPolicy == ListRefreshPolicy.quick),
          isTrue);
      expect(
          schedules.any((s) =>
              s.taskType == RefreshTaskType.sendPendingMessages &&
              s.sendMessagesMode == SendMessagesMode.sendAllUntilFailure),
          isTrue);
    });

    test('Battery Saver preset has correct schedules', () {
      final preset =
          SchedulerPreset.presets.firstWhere((p) => p.name == 'Battery Saver');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 4);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 240 &&
              s.refreshPolicy == ListRefreshPolicy.full),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 15 &&
              s.refreshPolicy == ListRefreshPolicy.watched),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 60 &&
              s.refreshPolicy == ListRefreshPolicy.quick),
          isTrue);
      expect(
          schedules
              .any((s) => s.taskType == RefreshTaskType.sendPendingMessages),
          isTrue);
    });

    test('Daily preset has correct schedules', () {
      final preset =
          SchedulerPreset.presets.firstWhere((p) => p.name == 'Daily');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 2);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 1440 &&
              s.refreshPolicy == ListRefreshPolicy.full),
          isTrue);
      expect(
          schedules
              .any((s) => s.taskType == RefreshTaskType.sendPendingMessages),
          isTrue);
    });

    test('Never (Manual Only) preset has correct schedules', () {
      final preset = SchedulerPreset.presets
          .firstWhere((p) => p.name == 'Never (Manual Only)');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 1);
      expect(
          schedules
              .any((s) => s.taskType == RefreshTaskType.sendPendingMessages),
          isTrue);
      expect(
          schedules.any((s) => s.taskType == RefreshTaskType.refresh), isFalse);
    });

    test('Hourly preset has correct schedules', () {
      final preset =
          SchedulerPreset.presets.firstWhere((p) => p.name == 'Hourly');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 4);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 60 &&
              s.refreshPolicy == ListRefreshPolicy.full),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 10 &&
              s.refreshPolicy == ListRefreshPolicy.watched),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 30 &&
              s.refreshPolicy == ListRefreshPolicy.quick),
          isTrue);
      expect(
          schedules
              .any((s) => s.taskType == RefreshTaskType.sendPendingMessages),
          isTrue);
    });

    test('Aggressive preset has correct schedules', () {
      final preset =
          SchedulerPreset.presets.firstWhere((p) => p.name == 'Aggressive');
      final schedules = preset.schedulesFactory();

      expect(schedules.length, 4);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 15 &&
              s.refreshPolicy == ListRefreshPolicy.full),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 2 &&
              s.refreshPolicy == ListRefreshPolicy.watched),
          isTrue);
      expect(
          schedules.any((s) =>
              s.intervalInMinutes == 5 &&
              s.refreshPolicy == ListRefreshPolicy.quick),
          isTrue);
      expect(
          schedules
              .any((s) => s.taskType == RefreshTaskType.sendPendingMessages),
          isTrue);
    });
  });
}
