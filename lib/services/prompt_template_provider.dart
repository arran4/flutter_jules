import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prompt_template.dart';

class PromptTemplateProvider with ChangeNotifier {
  static const _customTemplatesKey = 'custom_prompt_templates_v1';
  static const _recentPromptsKey = 'recent_prompts_v1';
  static const _disabledBuiltInKey = 'disabled_builtin_templates_v1';
  static const _maxRecentPrompts = 10;

  List<PromptTemplate> _customTemplates = [];
  List<String> _recentPrompts = [];
  Set<String> _disabledBuiltInTemplateIds = {};
  bool _isLoading = true;

  PromptTemplateProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  List<PromptTemplate> get customTemplates => _customTemplates;
  List<String> get recentPrompts => _recentPrompts;
  Set<String> get disabledBuiltInTemplateIds => _disabledBuiltInTemplateIds;

  final List<PromptTemplate> _builtInTemplates = [
    PromptTemplate(
      id: 'builtin_refactor',
      name: 'Refactor Code',
      description: 'Improve readability and performance',
      content: 'Refactor the selected code to improve readability, maintainability, and performance. Explain the changes you made.',
      isBuiltIn: true,
    ),
    PromptTemplate(
      id: 'builtin_tests',
      name: 'Write Tests',
      description: 'Generate unit tests',
      content: 'Write comprehensive unit tests for the selected code, covering happy paths and edge cases. Use the existing testing framework.',
      isBuiltIn: true,
    ),
    PromptTemplate(
      id: 'builtin_docs',
      name: 'Add Documentation',
      description: 'Add comments and docstrings',
      content: 'Add detailed documentation comments (docstrings) to the selected code, explaining the purpose of classes, methods, and parameters.',
      isBuiltIn: true,
    ),
    PromptTemplate(
      id: 'builtin_analyze',
      name: 'Analyze for Bugs',
      description: 'Find bugs and vulnerabilities',
      content: 'Analyze the selected code for potential bugs, logic errors, and security vulnerabilities. Suggest fixes for any issues found.',
      isBuiltIn: true,
    ),
     PromptTemplate(
      id: 'builtin_explain',
      name: 'Explain Code',
      description: 'Explain how the code works',
      content: 'Explain how the selected code works in detail, breaking it down step-by-step.',
      isBuiltIn: true,
    ),
  ];

  List<PromptTemplate> get builtInTemplates => _builtInTemplates;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Custom Templates
    final customJson = prefs.getString(_customTemplatesKey);
    if (customJson != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(customJson);
        _customTemplates = jsonList.map((j) => PromptTemplate.fromJson(j)).toList();
      } catch (e) {
        debugPrint('Error loading custom templates: $e');
      }
    }

    // Load Recent Prompts
    final recentList = prefs.getStringList(_recentPromptsKey);
    if (recentList != null) {
      _recentPrompts = recentList;
    }

    // Load Disabled Built-ins
    final disabledList = prefs.getStringList(_disabledBuiltInKey);
    if (disabledList != null) {
      _disabledBuiltInTemplateIds = disabledList.toSet();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveCustomTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_customTemplates.map((t) => t.toJson()).toList());
    await prefs.setString(_customTemplatesKey, jsonString);
  }

  Future<void> _saveRecentPrompts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentPromptsKey, _recentPrompts);
  }

  Future<void> _saveDisabledBuiltIns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_disabledBuiltInKey, _disabledBuiltInTemplateIds.toList());
  }

  // Custom Templates CRUD
  Future<void> addCustomTemplate(PromptTemplate template) async {
    _customTemplates.add(template);
    await _saveCustomTemplates();
    notifyListeners();
  }

  Future<void> updateCustomTemplate(PromptTemplate template) async {
    final index = _customTemplates.indexWhere((t) => t.id == template.id);
    if (index != -1) {
      _customTemplates[index] = template;
      await _saveCustomTemplates();
      notifyListeners();
    }
  }

  Future<void> deleteCustomTemplate(String id) async {
    _customTemplates.removeWhere((t) => t.id == id);
    await _saveCustomTemplates();
    notifyListeners();
  }

  // Recent Prompts
  Future<void> addRecentPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;

    // Remove if exists to move to top
    _recentPrompts.remove(prompt);
    _recentPrompts.insert(0, prompt);

    if (_recentPrompts.length > _maxRecentPrompts) {
      _recentPrompts = _recentPrompts.sublist(0, _maxRecentPrompts);
    }

    await _saveRecentPrompts();
    notifyListeners();
  }

  Future<void> deleteRecentPrompt(String prompt) async {
    _recentPrompts.remove(prompt);
    await _saveRecentPrompts();
    notifyListeners();
  }

  // Built-in Toggles
  Future<void> toggleBuiltIn(String id, bool enabled) async {
    if (enabled) {
      _disabledBuiltInTemplateIds.remove(id);
    } else {
      _disabledBuiltInTemplateIds.add(id);
    }
    await _saveDisabledBuiltIns();
    notifyListeners();
  }

  bool isBuiltInEnabled(String id) {
    return !_disabledBuiltInTemplateIds.contains(id);
  }
}
