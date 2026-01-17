import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:provider/provider.dart';
import 'services/activity_provider.dart';
import 'services/auth_provider.dart';
import 'services/dev_mode_provider.dart';
import 'services/github_provider.dart';
import 'services/session_provider.dart';
import 'services/source_provider.dart';
import 'services/filter_bookmark_provider.dart';
import 'services/bulk_action_preset_provider.dart';
import 'services/message_queue_provider.dart';
import 'services/settings_provider.dart';
import 'services/cache_service.dart';
import 'services/refresh_service.dart';
import 'services/bulk_action_executor.dart';
import 'services/notification_service.dart';
import 'services/notification_provider.dart';
import 'services/tags_provider.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'services/tray_service.dart';
import 'services/global_shortcut_focus_manager.dart';
import 'services/shortcut_registry.dart';
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';
import 'ui/widgets/help_dialog.dart';
import 'ui/session_helpers.dart';
import 'ui/widgets/notification_overlay.dart';
import 'intents.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationService>(create: (_) => NotificationService()),
        ChangeNotifierProvider(
            create: (_) => ShortcutRegistry()..initDefaults()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DevModeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProxyProvider<SettingsProvider, GithubProvider>(
          create: (context) => GithubProvider(context.read<SettingsProvider>()),
          update: (context, settings, github) => github!,
        ),
        ChangeNotifierProvider(create: (_) => FilterBookmarkProvider()),
        ChangeNotifierProvider(create: (_) => BulkActionPresetProvider()),
        ProxyProvider<DevModeProvider, CacheService>(
          update: (_, devMode, __) =>
              CacheService(isDevMode: devMode.isDevMode),
        ),
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
      child: const GlobalShortcutFocusManager(child: MyApp()),
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
    final settings = context.read<SettingsProvider>();
    if (settings.isInitialized) {
      _onSettingsChanged();
    }
    settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    context.read<SettingsProvider>().removeListener(_onSettingsChanged);
    _trayService?.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    final settings = context.read<SettingsProvider>();
    if (settings.trayEnabled && _trayService == null) {
      _initTrayService();
    } else if (!settings.trayEnabled && _trayService != null) {
      _trayService?.dispose();
      _trayService = null;
      trayManager.destroy();
    }
  }

  void _initTrayService() {
    _trayService = TrayService(
      onNewSession: () {
        if (navigatorKey.currentContext != null) {
          showNewSessionDialog(navigatorKey.currentContext!);
        }
      },
      onRefresh: () {
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated) {
          context.read<SessionProvider>().fetchSessions(
                auth.client,
                authToken: auth.token,
                force: true,
              );
          context.read<SourceProvider>().fetchSources(
                auth.client,
                authToken: auth.token,
                force: true,
              );
        }
      },
    );
    _trayService!.init();
  }

  @override
  Future<void> onWindowClose() async {
    if (context.read<SettingsProvider>().trayEnabled) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusManager = GlobalShortcutFocusManager.of(context);
    final shortcutRegistry = Provider.of<ShortcutRegistry>(context);

    return Focus(
      focusNode: focusManager.focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: shortcutRegistry.shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            ShowHelpIntent: CallbackAction<ShowHelpIntent>(
              onInvoke: (ShowHelpIntent intent) => showDialog(
                context: context,
                builder: (context) => const HelpDialog(),
              ),
            ),
          },
          child: GestureDetector(
            onTap: () {
              focusManager.requestFocus();
            },
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: "Arran's Flutter based jules client",
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
                  return const NotificationOverlay(child: SessionListScreen());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
