import 'package:flutter/material.dart';
import 'package:flutter_jules/models/activity_log.dart';

class ActivityProvider extends ChangeNotifier {
  final List<ActivityLog> _logs = [];

  List<ActivityLog> get logs => _logs;

  void addLog(String message) {
    _logs.add(ActivityLog(timestamp: DateTime.now(), message: message));
    notifyListeners();
  }
}
