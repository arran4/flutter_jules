import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'services/tray_service.dart';
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';
import 'ui/widgets/help_dialog.dart';
import 'ui/session_helpers.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class ShowHelpIntent extends Intent {
  const ShowHelpIntent();
}

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
        context.read<SessionProvider>().refreshSessions();
        context.read<SourceProvider>().refreshSources();
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
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
            LogicalKeyboardKey.slash): const ShowHelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ShowHelpIntent: CallbackAction<ShowHelpIntent>(
            onInvoke: (ShowHelpIntent intent) => showDialog(
              context: context,
              builder: (context) => const HelpDialog(),
            ),
          ),
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Jules API Client',
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
        ),
      ),
    );
  }
}
