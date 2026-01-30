import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter_jules/ui/app_container.dart';
import 'package:provider/provider.dart';

import '../../intents.dart';
import '../../models/app_shortcut_action.dart';
import '../../services/shortcut_registry.dart';
import '../../services/settings_provider.dart';
import '../../utils/app_shortcuts.dart';
import '../../utils/platform_utils.dart';
import '../themes.dart';
import '../widgets/help_dialog.dart';
import '../widgets/new_session_dialog.dart';

class NewSessionWindow extends StatefulWidget {
  const NewSessionWindow({super.key, required this.windowId});

  final int windowId;

  @override
  State<NewSessionWindow> createState() => _NewSessionWindowState();
}

class _NewSessionWindowState extends State<NewSessionWindow> {
  @override
  Widget build(BuildContext context) {
    return AppContainer(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final shortcutRegistry = Provider.of<ShortcutRegistry>(context);
          return Shortcuts(
            shortcuts: shortcutRegistry.shortcuts,
            child: Actions(
              actions: <Type, Action<Intent>>{
                GlobalActionIntent: CallbackAction<GlobalActionIntent>(
                  onInvoke: (GlobalActionIntent intent) {
                    return shortcutRegistry.dispatch(intent.action);
                  },
                ),
              },
              child: MaterialApp(
                theme: JulesTheme.getTheme(
                  settings.themeType,
                  Brightness.light,
                ),
                darkTheme: JulesTheme.getTheme(
                  settings.themeType,
                  Brightness.dark,
                ),
                themeMode: settings.themeMode,
                home: Scaffold(
                  body: NewSessionDialogWrapper(windowId: widget.windowId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewSessionDialogWrapper extends StatefulWidget {
  const NewSessionDialogWrapper({super.key, required this.windowId});

  final int windowId;

  @override
  State<NewSessionDialogWrapper> createState() =>
      _NewSessionDialogWrapperState();
}

class _NewSessionDialogWrapperState extends State<NewSessionDialogWrapper> {
  StreamSubscription<AppShortcutAction>? _actionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shortcutRegistry = context.read<ShortcutRegistry>();

      _actionSubscription = shortcutRegistry.onAction.listen((action) {
        if (!mounted) return;
        if (action == AppShortcutAction.showHelp) {
          showDialog(
            context: context,
            builder: (context) => const HelpDialog(),
          );
        }
      });

      registerGlobalShortcuts(shortcutRegistry, isMacOS: PlatformUtils.isMacOS);

      _showNewSessionDialog();
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    super.dispose();
  }

  void _showNewSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewSessionDialog(),
    ).then((_) {
      final controller = WindowController.fromWindowId(widget.windowId);
      controller.close();
    });
  }

  @override
  Widget build(BuildContext context) {
    // This container can be empty because the dialog is shown above it.
    return Container();
  }
}
