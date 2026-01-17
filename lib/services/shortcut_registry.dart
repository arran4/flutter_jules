import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../intents.dart';

class Shortcut {
  final ShortcutActivator activator;
  final Intent intent;
  final String description;

  Shortcut(this.activator, this.intent, this.description);
}

class ShortcutRegistry extends ChangeNotifier {
  final Map<ShortcutActivator, Intent> _shortcuts = {};
  final Map<Intent, String> _descriptions = {};

  Map<ShortcutActivator, Intent> get shortcuts => Map.unmodifiable(_shortcuts);
  Map<Intent, String> get descriptions => Map.unmodifiable(_descriptions);

  void register(Shortcut shortcut) {
    _shortcuts[shortcut.activator] = shortcut.intent;
    _descriptions[shortcut.intent] = shortcut.description;
    notifyListeners();
  }

  void unregister(Shortcut shortcut) {
    _shortcuts.remove(shortcut.activator);
    _descriptions.remove(shortcut.intent);
    notifyListeners();
  }

  void initDefaults() {
    register(Shortcut(
      const SingleActivator(LogicalKeyboardKey.keyN, control: true),
      const NewSessionIntent(),
      'New Session',
    ));
    register(Shortcut(
      const SingleActivator(LogicalKeyboardKey.slash,
          control: true, shift: true),
      const ShowHelpIntent(),
      'Show Shortcuts',
    ));
    register(Shortcut(
      const SingleActivator(LogicalKeyboardKey.enter, control: true),
      const SubmitIntent(),
      'Submit / Save',
    ));
  }
}
