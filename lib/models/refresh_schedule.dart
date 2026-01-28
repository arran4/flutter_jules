import 'package:uuid/uuid.dart';
import 'enums.dart';
import 'package:dartobjectutils/dartobjectutils.dart';

enum RefreshTaskType { refresh, sendPendingMessages }

enum SendMessagesMode { sendOne, sendAllUntilFailure }

class RefreshSchedule {
  String id;
  String name;
  int intervalInMinutes;
  bool isEnabled;
  RefreshTaskType taskType;
  ListRefreshPolicy? refreshPolicy;
  SendMessagesMode? sendMessagesMode;
  DateTime? lastRun;

  RefreshSchedule({
    String? id,
    required this.name,
    required this.intervalInMinutes,
    this.isEnabled = true,
    this.taskType = RefreshTaskType.refresh,
    this.refreshPolicy,
    this.sendMessagesMode,
    this.lastRun,
  }) : id = id ?? const Uuid().v4();

  factory RefreshSchedule.fromJson(Map<String, dynamic> json) {
    final refreshPolicyIndex = getNumberPropOrDefault<num?>(
      json,
      'refreshPolicy',
      null,
    )?.toInt();
    final sendMessagesModeIndex = getNumberPropOrDefault<num?>(
      json,
      'sendMessagesMode',
      null,
    )?.toInt();

    return RefreshSchedule(
      id: getStringPropOrDefault(json, 'id', null),
      name: getStringPropOrThrow(json, 'name'),
      intervalInMinutes:
          (getNumberPropOrThrow(json, 'intervalInMinutes') as num).toInt(),
      isEnabled: getBooleanPropOrDefault(json, 'isEnabled', true),
      taskType: RefreshTaskType.values[getNumberPropOrDefault(
        json,
        'taskType',
        RefreshTaskType.refresh.index,
      ).toInt()],
      refreshPolicy: refreshPolicyIndex != null
          ? ListRefreshPolicy.values[refreshPolicyIndex]
          : null,
      sendMessagesMode: sendMessagesModeIndex != null
          ? SendMessagesMode.values[sendMessagesModeIndex]
          : null,
      lastRun: json['lastRun'] != null
          ? DateTime.tryParse(json['lastRun'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'intervalInMinutes': intervalInMinutes,
      'isEnabled': isEnabled,
      'taskType': taskType.index,
      'refreshPolicy': refreshPolicy?.index,
      'sendMessagesMode': sendMessagesMode?.index,
      'lastRun': lastRun?.toIso8601String(),
    };
  }
}
