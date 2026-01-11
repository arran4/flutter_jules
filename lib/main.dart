import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

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
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    title: 'Jules',
    size: Size(1200, 800),
    center: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
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
        ChangeNotifierProxyProvider3<SettingsProvider, SessionProvider,
            SourceProvider, RefreshService>(
          create: (context) => RefreshService(
            context.read<SettingsProvider>(),
            context.read<SessionProvider>(),
            context.read<SourceProvider>(),
            context.read<AuthProvider>(),
          ),
          update: (_, settings, sessionProvider, sourceProvider, service) =>
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

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  Process? _trayProcess;
  late File _ipcFile;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _startTrayProcess();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _trayProcess?.kill();
    super.dispose();
  }

  Future<void> _startTrayProcess() async {
    final tempDir = await getTemporaryDirectory();
    _ipcFile = File(p.join(tempDir.path, 'tray.ipc'));

    String executable;
    if (Platform.isLinux) {
      executable = './tray/bin/tray_linux';
    } else if (Platform.isWindows) {
      executable = 'tray\\bin\\tray_windows.exe';
    } else {
      // macOS not supported yet, but we can add it later
      return;
    }

    try {
      _trayProcess = await Process.start(executable, []);
      _listenForTrayCommands();
    } catch (e) {
      print('Error starting tray process: $e');
    }
  }

  void _listenForTrayCommands() {
    final watcher = _ipcFile.watch();
    watcher.listen((event) async {
      if (event.type == FileSystemEvent.modify) {
        final command = await _ipcFile.readAsString();
        if (command == 'show') {
          windowManager.show();
        }
      }
    });
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
