import 'package:flutter/material.dart';

class GlobalShortcutFocusManager extends StatefulWidget {
  final Widget child;

  const GlobalShortcutFocusManager({super.key, required this.child});

  static GlobalShortcutFocusManagerState of(BuildContext context) {
    final state =
        context.findAncestorStateOfType<GlobalShortcutFocusManagerState>();
    if (state == null) {
      throw FlutterError(
          'GlobalShortcutFocusManager not found in context. Wrap your app in a GlobalShortcutFocusManager.');
    }
    return state;
  }

  @override
  GlobalShortcutFocusManagerState createState() =>
      GlobalShortcutFocusManagerState();
}

class GlobalShortcutFocusManagerState
    extends State<GlobalShortcutFocusManager> {
  final FocusNode _focusNode = FocusNode();

  FocusNode get focusNode => _focusNode;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
