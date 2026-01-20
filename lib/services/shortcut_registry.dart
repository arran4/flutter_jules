import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_shortcut_action.dart';
import '../intents.dart';

class Shortcut {
  final ShortcutActivator activator;
  final AppShortcutAction action;
  final String description;

  Shortcut(this.activator, this.action, this.description);
}

class ShortcutRegistry extends ChangeNotifier {
  final Map<ShortcutActivator, AppShortcutAction> _shortcuts = {};
  final Map<AppShortcutAction, String> _descriptions = {};
  final StreamController<AppShortcutAction> _actionController =
      StreamController.broadcast();

  Stream<AppShortcutAction> get onAction => _actionController.stream;

  Map<ShortcutActivator, Intent> get shortcuts {
    return _shortcuts.map((activator, action) {
      return MapEntry(activator, GlobalActionIntent(action));
    });
  }

  Map<ShortcutActivator, AppShortcutAction> get shortcutActions =>
      Map.unmodifiable(_shortcuts);

  Map<AppShortcutAction, String> get descriptions =>
      Map.unmodifiable(_descriptions);

  void register(Shortcut shortcut) {
    _shortcuts[shortcut.activator] = shortcut.action;
    _descriptions[shortcut.action] = shortcut.description;
    notifyListeners();
  }

  void unregister(Shortcut shortcut) {
    _shortcuts.remove(shortcut.activator);
    _descriptions.remove(shortcut.action);
    notifyListeners();
  }

  void dispatch(AppShortcutAction action) {
    _actionController.add(action);
  }

  @override
  void dispose() {
    _actionController.close();
    super.dispose();
  }
}
