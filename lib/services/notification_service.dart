import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationAction {
  showTask,
  openPr,
  showNew,
}

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationResponse> onNotificationResponse =
      StreamController<NotificationResponse>.broadcast();

  Stream<NotificationResponse> get onNotificationResponseStream =>
      onNotificationResponse.stream;

  void dispose() {
    onNotificationResponse.close();
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'jules_category',
          actions: [
            DarwinNotificationAction.plain('show_task', 'Show Task'),
            DarwinNotificationAction.plain('open_pr', 'Open PR'),
            DarwinNotificationAction.plain('show_new', 'Show New'),
          ],
        ),
      ],
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

/*
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Jules',
      appUserModelId: 'Jules',
    );
*/

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      // windows: initializationSettingsWindows,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        onNotificationResponse.add(response);
      },
    );
  }

  Future<void> showNotification(
    String title,
    String body, {
    String? payload,
    List<NotificationAction>? actions,
  }) async {
    final androidActions = actions?.map((action) {
      switch (action) {
        case NotificationAction.showTask:
          return const AndroidNotificationAction('show_task', 'Show Task');
        case NotificationAction.openPr:
          return const AndroidNotificationAction('open_pr', 'Open PR');
        case NotificationAction.showNew:
          return const AndroidNotificationAction('show_new', 'Show New');
      }
    }).toList();

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'jules_channel_id',
      'Jules Notifications',
      channelDescription: 'Notifications for Jules task updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      actions: androidActions,
    );

    final linuxActions = actions?.map((action) {
      switch (action) {
        case NotificationAction.showTask:
          return const LinuxNotificationAction(
              key: 'show_task', label: 'Show Task');
        case NotificationAction.openPr:
          return const LinuxNotificationAction(
              key: 'open_pr', label: 'Open PR');
        case NotificationAction.showNew:
          return const LinuxNotificationAction(
              key: 'show_new', label: 'Show New');
      }
    }).toList();

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      categoryIdentifier: 'jules_category',
      attachments: [],
    );

    final LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
      actions: linuxActions ?? [],
    );

/*
    const WindowsNotificationDetails windowsPlatformChannelSpecifics =
        WindowsNotificationDetails();
*/

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
      // windows: windowsPlatformChannelSpecifics,
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
