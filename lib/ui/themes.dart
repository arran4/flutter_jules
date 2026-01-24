import 'package:flutter/material.dart';

enum JulesThemeType { blue, green, purple, orange, red, teal, pink, indigo }

class JulesTheme {
  static ThemeData getTheme(JulesThemeType type, Brightness brightness) {
    final seedColor = _getSeedColor(type);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
    );
  }

  static Color _getSeedColor(JulesThemeType type) {
    switch (type) {
      case JulesThemeType.blue:
        return Colors.blue;
      case JulesThemeType.green:
        return Colors.green;
      case JulesThemeType.purple:
        return Colors.purple;
      case JulesThemeType.orange:
        return Colors.orange;
      case JulesThemeType.red:
        return Colors.red;
      case JulesThemeType.teal:
        return Colors.teal;
      case JulesThemeType.pink:
        return Colors.pink;
      case JulesThemeType.indigo:
        return Colors.indigo;
    }
  }

  static String getName(JulesThemeType type) {
    return type.name[0].toUpperCase() + type.name.substring(1);
  }
}
