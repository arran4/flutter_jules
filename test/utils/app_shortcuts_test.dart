import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide ShortcutRegistry;
import 'package:flutter_jules/services/shortcut_registry.dart';
import 'package:flutter_jules/utils/app_shortcuts.dart';
import 'package:flutter_jules/models/app_shortcut_action.dart';

void main() {
  group('AppShortcuts Tests', () {
    late ShortcutRegistry registry;

    setUp(() {
      registry = ShortcutRegistry();
    });

    bool hasActivator(Map<ShortcutActivator, AppShortcutAction> shortcuts, LogicalKeyboardKey trigger, {bool control = false, bool shift = false, bool alt = false, bool meta = false}) {
      for (var key in shortcuts.keys) {
        if (key is SingleActivator) {
          if (key.trigger == trigger &&
              key.control == control &&
              key.shift == shift &&
              key.alt == alt &&
              key.meta == meta) {
            return true;
          }
        }
      }
      return false;
    }

    test('registerGlobalShortcuts registers existing help shortcut (Ctrl+Shift+/)', () {
      registerGlobalShortcuts(registry, isMacOS: false);

      final shortcuts = registry.shortcutActions;

      // Ctrl + Shift + /
      final exists = hasActivator(shortcuts, LogicalKeyboardKey.slash, control: true, shift: true);

      expect(exists, isTrue, reason: 'Ctrl+Shift+/ should be registered');

      // Verify action
      // We need to find the key again to get the action, or assume if it exists it's correct (since we only register one action per key usually)
      // But let's check the action associated with it.
      var action;
      for (var entry in shortcuts.entries) {
         if (entry.key is SingleActivator) {
           var key = entry.key as SingleActivator;
           if (key.trigger == LogicalKeyboardKey.slash && key.control == true && key.shift == true) {
             action = entry.value;
             break;
           }
         }
      }
      expect(action, AppShortcutAction.showHelp);
    });

    test('registerGlobalShortcuts registers new help shortcut (Ctrl+/)', () {
      registerGlobalShortcuts(registry, isMacOS: false);

      final shortcuts = registry.shortcutActions;

      // Ctrl + /
      final exists = hasActivator(shortcuts, LogicalKeyboardKey.slash, control: true, shift: false);

      expect(exists, isTrue, reason: 'Ctrl+/ should be registered');

      // Verify action
      var action;
      for (var entry in shortcuts.entries) {
         if (entry.key is SingleActivator) {
           var key = entry.key as SingleActivator;
           if (key.trigger == LogicalKeyboardKey.slash && key.control == true && key.shift == false) {
             action = entry.value;
             break;
           }
         }
      }
      expect(action, AppShortcutAction.showHelp);
    });
  });
}
