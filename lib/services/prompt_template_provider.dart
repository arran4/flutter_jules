import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';

class PromptTemplateProvider extends ChangeNotifier {
  static const String _customTemplatesKey = 'custom_prompt_templates';
  static const String _recentPromptsKey = 'recent_prompt_templates';
  static const String _disabledBuiltInIdsKey = 'disabled_builtin_prompt_ids';
  static const int _maxRecentPrompts = 10;

  List<PromptTemplate> _customTemplates = [];
  List<PromptTemplate> _recentPrompts = [];
  List<String> _disabledBuiltInIds = [];
  bool _isInitialized = false;

  final List<PromptTemplate> _builtInTemplates = [
    const PromptTemplate(
      id: 'builtin_explain',
      name: 'Explain Code',
      content:
          'Explain the following code in detail, highlighting key logic and potential issues:',
      isBuiltIn: true,
    ),
    const PromptTemplate(
      id: 'builtin_refactor',
      name: 'Refactor Code',
      content:
          'Refactor the selected code to improve readability and maintainability. Apply best practices and design patterns where appropriate.',
      isBuiltIn: true,
    ),
    const PromptTemplate(
      id: 'builtin_test',
      name: 'Write Unit Tests',
      content:
          'Write comprehensive unit tests for the following code, covering happy paths and edge cases.',
      isBuiltIn: true,
    ),
    const PromptTemplate(
      id: 'builtin_docs',
      name: 'Add Documentation',
      content:
          'Add Javadoc/Docstring style documentation to the following code, explaining parameters, return values, and exceptions.',
      isBuiltIn: true,
    ),
    const PromptTemplate(
      id: 'builtin_bugs',
      name: 'Find Bugs',
      content:
          'Analyze the following code for potential bugs, security vulnerabilities, and performance bottlenecks.',
      isBuiltIn: true,
    ),
  ];

  List<PromptTemplate> get customTemplates => _customTemplates;
  List<PromptTemplate> get recentPrompts => _recentPrompts;

  List<PromptTemplate> get availableBuiltInTemplates {
    return _builtInTemplates
        .where((t) => !_disabledBuiltInIds.contains(t.id))
        .toList();
  }

  List<PromptTemplate> get allBuiltInTemplates => _builtInTemplates;

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    await _loadData();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Custom
    final customJson = prefs.getString(_customTemplatesKey);
    if (customJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(customJson);
        _customTemplates =
            decoded.map((j) => PromptTemplate.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Error loading custom templates: $e');
        _customTemplates = [];
      }
    }

    // Load Recent
    final recentJson = prefs.getString(_recentPromptsKey);
    if (recentJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(recentJson);
        _recentPrompts =
            decoded.map((j) => PromptTemplate.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Error loading recent prompts: $e');
        _recentPrompts = [];
      }
    }

    // Load Disabled IDs
    _disabledBuiltInIds = prefs.getStringList(_disabledBuiltInIdsKey) ?? [];
  }

  Future<void> _saveCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      _customTemplates.map((t) => t.toJson()).toList(),
    );
    await prefs.setString(_customTemplatesKey, jsonString);
    notifyListeners();
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      _recentPrompts.map((t) => t.toJson()).toList(),
    );
    await prefs.setString(_recentPromptsKey, jsonString);
    notifyListeners();
  }

  Future<void> _saveDisabledIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledBuiltInIdsKey, _disabledBuiltInIds);
    notifyListeners();
  }

  // Custom Template Operations
  Future<void> addCustomTemplate(String name, String content) async {
    final newTemplate = PromptTemplate(
      id: const Uuid().v4(),
      name: name,
      content: content,
      isBuiltIn: false,
    );
    _customTemplates.add(newTemplate);
    await _saveCustom();
  }

  Future<void> updateCustomTemplate(
    String id,
    String name,
    String content,
  ) async {
    final index = _customTemplates.indexWhere((t) => t.id == id);
    if (index != -1) {
      _customTemplates[index] = _customTemplates[index].copyWith(
        name: name,
        content: content,
      );
      await _saveCustom();
    }
  }

  Future<void> deleteCustomTemplate(String id) async {
    _customTemplates.removeWhere((t) => t.id == id);
    await _saveCustom();
  }

  // Recent Prompt Operations
  Future<void> addRecentPrompt(String content) async {
    if (content.trim().isEmpty) return;

    // Remove if exists to move to top
    _recentPrompts.removeWhere((t) => t.content == content);

    final newRecent = PromptTemplate(
      id: const Uuid().v4(), // Unique ID for list handling
      name: content.length > 50 ? '${content.substring(0, 50)}...' : content,
      content: content,
      isBuiltIn: false,
    );

    _recentPrompts.insert(0, newRecent);

    if (_recentPrompts.length > _maxRecentPrompts) {
      _recentPrompts = _recentPrompts.sublist(0, _maxRecentPrompts);
    }

    await _saveRecent();
  }

  Future<void> deleteRecentPrompt(String id) async {
    _recentPrompts.removeWhere((t) => t.id == id);
    await _saveRecent();
  }

  // Built-in Operations
  bool isBuiltInDisabled(String id) {
    return _disabledBuiltInIds.contains(id);
  }

  Future<void> toggleBuiltIn(String id, bool enabled) async {
    if (enabled) {
      _disabledBuiltInIds.remove(id);
    } else {
      if (!_disabledBuiltInIds.contains(id)) {
        _disabledBuiltInIds.add(id);
      }
    }
    await _saveDisabledIds();
  }
}
