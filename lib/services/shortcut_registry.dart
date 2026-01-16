import 'package:flutter/material.dart';

class Shortcut {
  final LogicalKeySet keys;
  final Intent intent;
  final String description;

  Shortcut(this.keys, this.intent, this.description);
}

class ShortcutRegistry extends ChangeNotifier {
  final Map<LogicalKeySet, Intent> _shortcuts = {};
  final Map<Intent, String> _descriptions = {};

  Map<LogicalKeySet, Intent> get shortcuts => Map.unmodifiable(_shortcuts);
  Map<Intent, String> get descriptions => Map.unmodifiable(_descriptions);

  void register(Shortcut shortcut) {
    _shortcuts[shortcut.keys] = shortcut.intent;
    _descriptions[shortcut.intent] = shortcut.description;
    notifyListeners();
  }

  void unregister(Shortcut shortcut) {
    _shortcuts.remove(shortcut.keys);
    _descriptions.remove(shortcut.intent);
    notifyListeners();
  }
}
