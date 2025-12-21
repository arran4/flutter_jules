import 'package:flutter/material.dart';

class DevModeProvider extends ChangeNotifier {
  bool _isDevMode = false;
  bool _enableApiLogging = false;

  bool get isDevMode => _isDevMode;
  bool get enableApiLogging => _enableApiLogging;

  void toggleDevMode(bool value) {
    _isDevMode = value;
    notifyListeners();
  }

  void toggleApiLogging(bool value) {
    _enableApiLogging = value;
    notifyListeners();
  }
}
