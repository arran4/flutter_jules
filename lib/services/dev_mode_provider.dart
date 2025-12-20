import 'package:flutter/material.dart';

class DevModeProvider extends ChangeNotifier {
  bool _isDevMode = false;

  bool get isDevMode => _isDevMode;

  void toggleDevMode(bool value) {
    _isDevMode = value;
    notifyListeners();
  }
}
