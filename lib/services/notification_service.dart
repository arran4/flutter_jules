import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String?> onNotificationPayload =
      StreamController<String?>.broadcast();

  Stream<String?> get onNotificationPayloadStream => onNotificationPayload.stream;

  void dispose() {
    onNotificationPayload.close();
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          onNotificationPayload.add(response.payload);
        }
      },
    );
  }

  Future<void> showNotification(String title, String body, {String? payload}) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'jules_channel_id',
      'Jules Notifications',
      channelDescription: 'Notifications for Jules task updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('show_task', 'Show Task'),
        const AndroidNotificationAction('open_pr', 'Open PR'),
      ],
    );

    // TODO(iOS/macOS support): Implement actions for DarwinNotificationDetails.
    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
