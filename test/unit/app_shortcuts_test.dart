import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    hide
        ShortcutRegistry; // Explicitly import widgets just in case, but hide ShortcutRegistry
import 'package:flutter_jules/services/shortcut_registry.dart';
import 'package:flutter_jules/utils/app_shortcuts.dart';
import 'package:flutter_jules/models/app_shortcut_action.dart';

void main() {
  test('registerGlobalShortcuts registers correct shortcuts for macOS', () {
    final registry = ShortcutRegistry();
    registerGlobalShortcuts(registry, isMacOS: true);

    final shortcuts = registry.shortcutActions;

    // Check Help
    bool helpFound = false;
    shortcuts.forEach((activator, action) {
      if (action == AppShortcutAction.showHelp) {
        expect(activator, isA<SingleActivator>());
        final single = activator as SingleActivator;
        expect(single.trigger, LogicalKeyboardKey.slash);
        expect(single.meta, isTrue, reason: 'Should use Meta on macOS');
        expect(
          single.control,
          isFalse,
          reason: 'Should not use Control on macOS',
        );
        if (single.shift) {
          expect(single.shift, isTrue);
        } else {
          expect(single.shift, isFalse);
        }
        helpFound = true;
      }
    });
    expect(helpFound, isTrue, reason: 'Help shortcut not found for macOS');

    // Check New Session
    bool newSessionFound = false;
    shortcuts.forEach((activator, action) {
      if (action == AppShortcutAction.newSession) {
        final single = activator as SingleActivator;
        expect(single.trigger, LogicalKeyboardKey.keyN);
        expect(single.meta, isTrue);
        expect(single.control, isFalse);
        newSessionFound = true;
      }
    });
    expect(
      newSessionFound,
      isTrue,
      reason: 'New Session shortcut not found for macOS',
    );
  });

  test('registerGlobalShortcuts registers correct shortcuts for non-macOS', () {
    final registry = ShortcutRegistry();
    registerGlobalShortcuts(registry, isMacOS: false);

    final shortcuts = registry.shortcutActions;

    // Check Help
    bool helpFound = false;
    shortcuts.forEach((activator, action) {
      if (action == AppShortcutAction.showHelp) {
        final single = activator as SingleActivator;
        expect(single.trigger, LogicalKeyboardKey.slash);
        expect(single.meta, isFalse);
        expect(
          single.control,
          isTrue,
          reason: 'Should use Control on non-macOS',
        );
        if (single.shift) {
          expect(single.shift, isTrue);
        } else {
          expect(single.shift, isFalse);
        }
        helpFound = true;
      }
    });
    expect(helpFound, isTrue, reason: 'Help shortcut not found for non-macOS');

    // Check New Session
    bool newSessionFound = false;
    shortcuts.forEach((activator, action) {
      if (action == AppShortcutAction.newSession) {
        final single = activator as SingleActivator;
        expect(single.trigger, LogicalKeyboardKey.keyN);
        expect(single.meta, isFalse);
        expect(single.control, isTrue);
        newSessionFound = true;
      }
    });
    expect(
      newSessionFound,
      isTrue,
      reason: 'New Session shortcut not found for non-macOS',
    );
  });
}
