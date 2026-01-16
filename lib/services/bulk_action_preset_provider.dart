import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bulk_action_preset.dart';

class BulkActionPresetProvider with ChangeNotifier {
  static const _presetsKey = 'bulk_action_presets_v1';
  static const _defaultsAssetPath = 'assets/default_bulk_action_presets.json';

  List<BulkActionPreset> _presets = [];
  final List<BulkActionPreset> _defaultPresets = [];
  bool _isLoading = true;

  List<BulkActionPreset> get presets => _presets;
  List<BulkActionPreset> get defaultPresets => _defaultPresets;
  bool get isLoading => _isLoading;

  BulkActionPresetProvider() {
    _initFuture = _init();
  }

  Future<void>? _initFuture;
  Future<void> get initialized => _initFuture ?? Future.value();

  Future<void> _init() async {
    await _loadDefaults();
    await _loadPresets();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadDefaults() async {
    try {
      final jsonString = await rootBundle.loadString(_defaultsAssetPath);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _defaultPresets.clear();
      _defaultPresets.addAll(
        jsonList.map((json) => BulkActionPreset.fromJson(json)),
      );
    } catch (e) {
      debugPrint('Failed to load default bulk action presets: $e');
      _defaultPresets.clear();
    }
  }

  Future<void> _loadPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_presetsKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _presets =
            jsonList.map((json) => BulkActionPreset.fromJson(json)).toList();
      } else {
        _presets = List.from(_defaultPresets);
        await _savePresets();
      }
    } catch (e) {
      _presets = List.from(_defaultPresets);
    }
  }

  Future<void> _savePresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_presets.map((p) => p.toJson()).toList());
      await prefs.setString(_presetsKey, jsonString);
    } catch (e) {
      debugPrint('Failed to save bulk action presets: $e');
    }
  }

  Future<void> addPreset(BulkActionPreset preset) async {
    _presets.removeWhere((p) => p.name == preset.name);
    _presets.add(preset);
    await _savePresets();
    notifyListeners();
  }

  Future<void> deletePreset(String presetName) async {
    _presets.removeWhere((p) => p.name == presetName);
    await _savePresets();
    notifyListeners();
  }

  bool isSystemPreset(String name) {
    return _defaultPresets.any((d) => d.name == name);
  }

  List<BulkActionPreset> getRestorableSystemPresets() {
    return _defaultPresets
        .where((d) => !_presets.any((b) => b.name == d.name))
        .toList();
  }

  Future<void> restoreSystemPreset(String name) async {
    try {
      final systemPreset = _defaultPresets.firstWhere(
        (d) => d.name == name,
      );
      if (!_presets.any((p) => p.name == name)) {
        await addPreset(systemPreset);
      }
    } catch (e) {
      // Handle not found
    }
  }

  Future<void> updatePreset(
    String oldName,
    BulkActionPreset newPreset,
  ) async {
    final index = _presets.indexWhere((p) => p.name == oldName);
    if (index != -1) {
      _presets[index] = newPreset;
      await _savePresets();
      notifyListeners();
    }
  }

  BulkActionPreset? getPresetByName(String name) {
    try {
      return _presets.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }

  String exportToJson() {
    final jsonList = _presets.map((p) => p.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  Future<void> importFromJson(String jsonString, {bool merge = true}) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final imported = jsonList
          .map(
              (json) => BulkActionPreset.fromJson(json as Map<String, dynamic>))
          .toList();

      if (merge) {
        for (final preset in imported) {
          _presets.removeWhere((p) => p.name == preset.name);
          _presets.add(preset);
        }
      } else {
        _presets = imported;
      }

      await _savePresets();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to import presets: $e');
    }
  }

  Future<void> reorderPreset(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final preset = _presets.removeAt(oldIndex);
    _presets.insert(newIndex, preset);
    await _savePresets();
    notifyListeners();
  }
}
