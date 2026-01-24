import 'dart:convert';
import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/session_provider.dart';
import 'services/source_provider.dart';
import 'services/settings_provider.dart';
import 'services/refresh_service.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'services/tray_service.dart';
import 'services/global_shortcut_focus_manager.dart';
import 'services/shortcut_registry.dart';
import 'ui/app_container.dart';
import 'ui/themes.dart';
import 'ui/screens/new_session_window.dart';
import 'ui/screens/session_list_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/source_list_screen.dart';
import 'ui/widgets/help_dialog.dart';

import 'ui/widgets/notification_overlay.dart';
import 'models/app_shortcut_action.dart';
import 'intents.dart';
import 'utils/app_shortcuts.dart';
import 'dart:io';

final navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    runApp(NewSessionWindow(
      windowId: windowId,
    ));
  } else {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await NotificationService().init();

    runApp(const AppContainer(
      child: GlobalShortcutFocusManager(child: MyApp()),
    ));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  TrayService? _trayService;
  StreamSubscription<AppShortcutAction>? _actionSubscription;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Initialize services
    context.read<RefreshService>();
    final settings = context.read<SettingsProvider>();
    NotificationService().settings = settings;
    if (settings.isInitialized) {
      _onSettingsChanged();
    }
    settings.addListener(_onSettingsChanged);
    // Register the global shortcuts here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shortcutRegistry = context.read<ShortcutRegistry>();

      _actionSubscription = shortcutRegistry.onAction.listen((action) {
        if (!mounted) return;
        if (action == AppShortcutAction.showHelp) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null) {
            showDialog(
              context: ctx, // ignore: use_build_context_synchronously
              builder: (context) => const HelpDialog(),
            );
          }
        }
      });

      registerGlobalShortcuts(shortcutRegistry, isMacOS: Platform.isMacOS);
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
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

    if (settings.trayEnabled && settings.hideToTray) {
      windowManager.setPreventClose(true);
    } else {
      windowManager.setPreventClose(false);
    }
  }

  void _initTrayService() {
    _trayService = TrayService(
      onNewSession: () async {
        final window = await DesktopMultiWindow.createWindow(
          jsonEncode({
            'type': 'new_session',
          }),
        );
        window
          ..setFrame(const Offset(0, 0) & const Size(800, 600))
          ..center()
          ..setTitle('New Session')
          ..show();
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
    final settings = context.read<SettingsProvider>();
    if (settings.trayEnabled && settings.hideToTray) {
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
            GlobalActionIntent: CallbackAction<GlobalActionIntent>(
              onInvoke: (GlobalActionIntent intent) =>
                  shortcutRegistry.dispatch(intent.action),
            ),
          },
          child: GestureDetector(
            onTap: () {
              focusManager.requestFocus();
            },
            child: Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return MaterialApp(
                  navigatorKey: navigatorKey,
                  title: "Arran's Flutter based jules client",
                  debugShowCheckedModeBanner: false,
                  theme:
                      JulesTheme.getTheme(settings.themeType, Brightness.light),
                  darkTheme:
                      JulesTheme.getTheme(settings.themeType, Brightness.dark),
                  themeMode: settings.themeMode,
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
                      return const NotificationOverlay(
                          child: SessionListScreen());
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
