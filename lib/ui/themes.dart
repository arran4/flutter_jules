import 'package:flutter/material.dart';

class JulesTheme {
  final String id;
  final String name;
  final ThemeData themeData;

  JulesTheme({
    required this.id,
    required this.name,
    required this.themeData,
  });
}

final List<JulesTheme> sampleThemes = [
  JulesTheme(
    id: 'default_light',
    name: 'Default Light',
    themeData: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.light,
    ),
  ),
  JulesTheme(
    id: 'default_dark',
    name: 'Default Dark',
    themeData: ThemeData(
      primarySwatch: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.dark,
    ),
  ),
];
