import 'package:flutter/widgets.dart';
import 'models/app_shortcut_action.dart';

class GlobalActionIntent extends Intent {
  final AppShortcutAction action;
  const GlobalActionIntent(this.action);
}
