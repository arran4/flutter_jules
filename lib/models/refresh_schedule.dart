import 'package:uuid/uuid.dart';
import '../services/settings_provider.dart';

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
    return RefreshSchedule(
      id: json['id'],
      name: json['name'],
      intervalInMinutes: json['intervalInMinutes'],
      isEnabled: json['isEnabled'],
      taskType: RefreshTaskType.values[json['taskType']],
      refreshPolicy: json['refreshPolicy'] != null
          ? ListRefreshPolicy.values[json['refreshPolicy']]
          : null,
      sendMessagesMode: json['sendMessagesMode'] != null
          ? SendMessagesMode.values[json['sendMessagesMode']]
          : null,
      lastRun:
          json['lastRun'] != null ? DateTime.tryParse(json['lastRun']) : null,
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
