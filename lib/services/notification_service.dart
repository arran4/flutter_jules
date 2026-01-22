import 'dart:async';
import 'dart:collection';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationAction {
  showTask,
  openPr,
  showNew,
}

class _QueuedNotification {
  final String title;
  final String body;
  final String? payload;
  final List<NotificationAction>? actions;

  _QueuedNotification({
    required this.title,
    required this.body,
    this.payload,
    this.actions,
  });
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

  final Queue<_QueuedNotification> _notificationQueue = Queue();
  bool _isProcessing = false;
  _QueuedNotification? _currentNotification;
  _QueuedNotification? _lastShownNotification;
  DateTime? _lastShownTime;
  SettingsProvider? settings;

  static const Duration _notificationDelay = Duration(milliseconds: 2500);
  static const Duration _debounceTime = Duration(seconds: 5);

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
    if (settings?.enableDebounce ?? true) {
      // Debounce check against queue
      final isDuplicateInQueue =
          _notificationQueue.any((n) => n.title == title && n.body == body);
      if (isDuplicateInQueue) return;

      // Debounce check against currently processing
      if (_currentNotification != null &&
          _currentNotification!.title == title &&
          _currentNotification!.body == body) {
        return;
      }

      // Debounce check against last shown
      if (_lastShownNotification != null &&
          _lastShownNotification!.title == title &&
          _lastShownNotification!.body == body &&
          _lastShownTime != null &&
          DateTime.now().difference(_lastShownTime!) < _debounceTime) {
        return;
      }
    }

    _notificationQueue.add(_QueuedNotification(
      title: title,
      body: body,
      payload: payload,
      actions: actions,
    ));

    if (!_isProcessing) {
      // Don't await the processing, let it run in background
      unawaited(_processQueue());
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_notificationQueue.isNotEmpty) {
      _currentNotification = _notificationQueue.removeFirst();

      try {
        await _show(_currentNotification!);
        _lastShownNotification = _currentNotification;
        _lastShownTime = DateTime.now();
      } catch (e) {
        // If showing fails, we just continue to the next one
        // In a real app we might want to log this
      } finally {
        _currentNotification = null;
      }

      if (_notificationQueue.isNotEmpty) {
        if (_lastShownTime != null) {
          final elapsed = DateTime.now().difference(_lastShownTime!);
          final remaining = _notificationDelay - elapsed;
          if (remaining > Duration.zero) {
            await Future.delayed(remaining);
          }
        } else {
          // If we haven't shown any yet (or failed), use default delay to be safe
          await Future.delayed(_notificationDelay);
        }
      }
    }

    _isProcessing = false;
  }

  Future<void> _show(_QueuedNotification notification) async {
    final androidActions = notification.actions?.map((action) {
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

    final linuxActions = notification.actions?.map((action) {
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
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: notification.payload,
    );
  }
}
