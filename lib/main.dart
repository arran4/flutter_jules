import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'services/auth_provider.dart';
import 'services/dev_mode_provider.dart';
import 'services/github_provider.dart';
import 'services/session_provider.dart';
import 'services/source_provider.dart';
import 'services/filter_bookmark_provider.dart';
import 'services/message_queue_provider.dart';
import 'services/settings_provider.dart';
import 'services/cache_service.dart';
import 'services/refresh_service.dart';
import 'services/bulk_action_executor.dart';
import 'services/notification_service.dart';
import 'services/tags_provider.dart';
import 'services/tray_service.dart';
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';
import 'ui/widgets/new_session_dialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationService>(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DevModeProvider()),
        ChangeNotifierProvider(create: (_) => GithubProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => FilterBookmarkProvider()),
        ProxyProvider<DevModeProvider, CacheService>(
          update: (_, devMode, __) =>
              CacheService(isDevMode: devMode.isDevMode),
        ),
        ChangeNotifierProxyProvider2<CacheService, GithubProvider,
            SessionProvider>(
          create: (_) => SessionProvider(),
          update: (_, cache, github, session) => session!
            ..setCacheService(cache)
            ..setGithubProvider(github),
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
        ChangeNotifierProxyProvider4<SettingsProvider, SessionProvider,
            SourceProvider, NotificationService, RefreshService>(
          create: (context) => RefreshService(
            context.read<SettingsProvider>(),
            context.read<SessionProvider>(),
            context.read<SourceProvider>(),
            context.read<AuthProvider>(),
            context.read<NotificationService>(),
          ),
          update: (
            _,
            settings,
            sessionProvider,
            sourceProvider,
            notificationService,
            service,
          ) =>
              service!,
        ),
        ChangeNotifierProxyProvider3<SessionProvider, AuthProvider,
            GithubProvider, BulkActionExecutor>(
          create: (context) => BulkActionExecutor(
            sessionProvider: context.read<SessionProvider>(),
            julesClient: context.read<AuthProvider>().client,
            authProvider: context.read<AuthProvider>(),
            githubProvider: context.read<GithubProvider>(),
          ),
          update: (context, session, auth, github, executor) => executor!,
        ),
        ChangeNotifierProxyProvider<SessionProvider, TagsProvider>(
          create: (context) => TagsProvider(context.read<SessionProvider>()),
          update: (_, sessionProvider, tagsProvider) =>
              tagsProvider ?? TagsProvider(sessionProvider),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  TrayService? _trayService;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTrayService();
    context.read<SettingsProvider>().addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _trayService?.destroy();
    context.read<SettingsProvider>().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    final settings = context.read<SettingsProvider>();
    if (settings.showTrayIcon) {
      _initTrayService();
    } else {
      _trayService?.destroy();
      _trayService = null;
    }
  }

  void _initTrayService() {
    final settings = context.read<SettingsProvider>();
    if (!settings.showTrayIcon || _trayService != null) {
      return;
    }

    _trayService = TrayService(
      onNewSession: _handleNewSession,
      onRefresh: _handleRefresh,
    )..init();

    windowManager.setPreventClose(true);
  }

  void _handleNewSession() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      showDialog(
        context: navigator.context,
        builder: (context) => const NewSessionDialog(),
      );
    }
  }

  void _handleRefresh() {
    final refreshService = context.read<RefreshService>();
    refreshService.triggerRefresh();
  }

  @override
  Future<void> onWindowClose() async {
    final settings = context.read<SettingsProvider>();
    if (settings.showTrayIcon) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  void onWindowDestroy() {
    _trayService?.destroy();
    super.onWindowDestroy();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jules API Client',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/sources_raw': (context) => const SourceListScreen(),
      },
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }
          return const SessionListScreen();
        },
      ),
    );
  }
}
