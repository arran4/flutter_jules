import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ShortcutRegistry;
import '../services/shortcut_registry.dart';
import '../models/app_shortcut_action.dart';

void registerGlobalShortcuts(
  ShortcutRegistry registry, {
  bool isMacOS = false,
}) {
  // Help: Ctrl+? (Windows/Linux) or Cmd+? (macOS)
  registry.register(
    Shortcut(
      SingleActivator(
        LogicalKeyboardKey.slash,
        control: !isMacOS,
        meta: isMacOS,
        shift: true,
      ),
      AppShortcutAction.showHelp,
      'Show Help',
    ),
  );

  // Help: Ctrl+/ (Windows/Linux) or Cmd+/ (macOS)
  registry.register(
    Shortcut(
      SingleActivator(
        LogicalKeyboardKey.slash,
        control: !isMacOS,
        meta: isMacOS,
        shift: false,
      ),
      AppShortcutAction.showHelp,
      'Show Help',
    ),
  );

  // New Session: Ctrl+N (Windows/Linux) or Cmd+N (macOS)
  registry.register(
    Shortcut(
      SingleActivator(
        LogicalKeyboardKey.keyN,
        control: !isMacOS,
        meta: isMacOS,
      ),
      AppShortcutAction.newSession,
      'New Session',
    ),
  );
}
