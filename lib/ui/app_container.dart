import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/activity_provider.dart';
import '../services/auth_provider.dart';
import '../services/bulk_action_executor.dart';
import '../services/bulk_action_preset_provider.dart';
import '../services/cache_service.dart';
import '../services/dev_mode_provider.dart';
import '../services/filter_bookmark_provider.dart';
import '../services/github_provider.dart';
import '../services/message_queue_provider.dart';
import '../services/notification_provider.dart';
import '../services/notification_service.dart';
import '../services/refresh_service.dart';
import '../services/session_provider.dart';
import '../services/settings_provider.dart';
import '../services/shortcut_registry.dart' as jules_shortcuts;
import '../services/source_provider.dart';
import '../services/tags_provider.dart';
import '../services/timer_service.dart';

class AppContainer extends StatelessWidget {
  final Widget child;

  const AppContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NotificationService>(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => ShortcutRegistry()),
        ChangeNotifierProvider(create: (_) => TimerService()),
        ChangeNotifierProvider(
          create: (_) => jules_shortcuts.ShortcutRegistry(),
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DevModeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ProxyProvider<DevModeProvider, CacheService>(
          update: (_, devMode, __) =>
              CacheService(isDevMode: devMode.isDevMode),
        ),
        ChangeNotifierProxyProvider2<SettingsProvider, CacheService,
            GithubProvider>(
          create: (context) => GithubProvider(
            context.read<SettingsProvider>(),
            context.read<CacheService>(),
          ),
          update: (context, settings, cache, github) => github!,
        ),
        ChangeNotifierProvider(create: (_) => FilterBookmarkProvider()),
        ChangeNotifierProvider(create: (_) => BulkActionPresetProvider()),
        ChangeNotifierProxyProvider3<CacheService, GithubProvider,
            NotificationProvider, SessionProvider>(
          create: (_) => SessionProvider(),
          update: (_, cache, github, notifications, session) => session!
            ..setCacheService(cache)
            ..setGithubProvider(github)
            ..setNotificationProvider(notifications),
        ),
        ChangeNotifierProxyProvider<CacheService, SourceProvider>(
          create: (_) => SourceProvider(),
          update: (_, cache, source) => source!..setCacheService(cache),
        ),
        ChangeNotifierProxyProvider2<CacheService, AuthProvider,
            MessageQueueProvider>(
          create: (_) => MessageQueueProvider(),
          update: (_, cache, auth, queue) =>
              queue!..setCacheService(cache, auth.token),
        ),
        ChangeNotifierProxyProvider6<
            SettingsProvider,
            SessionProvider,
            SourceProvider,
            NotificationService,
            MessageQueueProvider,
            ActivityProvider,
            RefreshService>(
          create: (context) => RefreshService(
            context.read<SettingsProvider>(),
            context.read<SessionProvider>(),
            context.read<SourceProvider>(),
            context.read<AuthProvider>(),
            context.read<NotificationService>(),
            context.read<MessageQueueProvider>(),
            context.read<ActivityProvider>(),
            context.read<TimerService>(),
          ),
          update: (
            _,
            settings,
            sessionProvider,
            sourceProvider,
            notificationService,
            messageQueueProvider,
            activityProvider,
            service,
          ) =>
              service!,
        ),
        ChangeNotifierProxyProvider4<SessionProvider, AuthProvider,
            GithubProvider, SettingsProvider, BulkActionExecutor>(
          create: (context) => BulkActionExecutor(
            sessionProvider: context.read<SessionProvider>(),
            julesClient: context.read<AuthProvider>().client,
            authProvider: context.read<AuthProvider>(),
            githubProvider: context.read<GithubProvider>(),
            settingsProvider: context.read<SettingsProvider>(),
          ),
          update: (context, session, auth, github, settings, executor) =>
              executor!,
        ),
        ChangeNotifierProxyProvider<SessionProvider, TagsProvider>(
          create: (context) => TagsProvider(context.read<SessionProvider>()),
          update: (_, sessionProvider, tagsProvider) =>
              tagsProvider ?? TagsProvider(sessionProvider),
        ),
      ],
      child: child,
    );
  }
}
