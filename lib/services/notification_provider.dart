import 'package:flutter/material.dart';

enum NotificationActionType { showGithubPatDialog }

class NotificationMessage {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationActionType? actionType;
  final String? actionLabel;

  NotificationMessage({
    required this.id,
    required this.title,
    required this.message,
    this.type = NotificationType.info,
    this.actionType,
    this.actionLabel,
  });
}

enum NotificationType { info, warning, error }

class NotificationProvider extends ChangeNotifier {
  final List<NotificationMessage> _notifications = [];
  List<NotificationMessage> get notifications => _notifications;

  void addNotification(NotificationMessage notification) {
    _notifications.add(notification);
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
