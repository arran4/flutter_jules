import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_bookmark.dart';

class FilterBookmarkProvider with ChangeNotifier {
  static const _bookmarksKey = 'filter_bookmarks_v1';
  static const _defaultsAssetPath = 'assets/default_bookmarks.json';

  List<FilterBookmark> _bookmarks = [];
  final List<FilterBookmark> _defaultBookmarks = [];
  bool _isLoading = true;

  List<FilterBookmark> get bookmarks => _bookmarks;
  List<FilterBookmark> get defaultBookmarks => _defaultBookmarks;
  bool get isLoading => _isLoading;

  FilterBookmarkProvider() {
    _initFuture = _init();
  }

  Future<void>? _initFuture;
  Future<void> get initialized => _initFuture ?? Future.value();

  Future<void> _init() async {
    await _loadDefaults();
    await _loadBookmarks();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadDefaults() async {
    try {
      final jsonString = await rootBundle.loadString(_defaultsAssetPath);
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _defaultBookmarks.clear();
      _defaultBookmarks.addAll(
        jsonList.map((json) => FilterBookmark.fromJson(json)),
      );
    } catch (e) {
      // Failed to load or parse default bookmarks, continue with empty list
      _defaultBookmarks.clear();
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_bookmarksKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _bookmarks =
            jsonList.map((json) => FilterBookmark.fromJson(json)).toList();
      } else {
        // No saved bookmarks, initialize with defaults
        _bookmarks = List.from(_defaultBookmarks);
        await _saveBookmarks();
      }
    } catch (e) {
      // Error loading, fallback to defaults
      _bookmarks = List.from(_defaultBookmarks);
    }
  }

  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_bookmarks.map((b) => b.toJson()).toList());
      await prefs.setString(_bookmarksKey, jsonString);
    } catch (e) {
      // Handle save error
    }
  }

  Future<void> addBookmark(FilterBookmark bookmark) async {
    // Prevent duplicates by name
    _bookmarks.removeWhere((b) => b.name == bookmark.name);
    _bookmarks.add(bookmark);
    _bookmarks.sort((a, b) => a.name.compareTo(b.name));
    await _saveBookmarks();
    notifyListeners();
  }

  Future<void> deleteBookmark(String bookmarkName) async {
    _bookmarks.removeWhere((b) => b.name == bookmarkName);
    await _saveBookmarks();
    notifyListeners();
  }

  bool isSystemBookmark(String name) {
    return _defaultBookmarks.any((d) => d.name == name);
  }

  List<FilterBookmark> getRestorableSystemBookmarks() {
    return _defaultBookmarks
        .where((d) => !_bookmarks.any((b) => b.name == d.name))
        .toList();
  }

  Future<void> restoreSystemBookmark(String name) async {
    try {
      final systemBookmark = _defaultBookmarks.firstWhere(
        (d) => d.name == name,
      );
      // Ensure we don't have a duplicate name before adding (though getRestorable checks this)
      if (!_bookmarks.any((b) => b.name == name)) {
        await addBookmark(systemBookmark);
      }
    } catch (e) {
      // Handle not found
    }
  }

  Future<void> updateBookmark(
    String oldName,
    FilterBookmark newBookmark,
  ) async {
    final index = _bookmarks.indexWhere((b) => b.name == oldName);
    if (index != -1) {
      _bookmarks[index] = newBookmark;
      await _saveBookmarks();
      notifyListeners();
    }
  }

  FilterBookmark? getBookmarkByName(String name) {
    try {
      return _bookmarks.firstWhere((b) => b.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<void> copyBookmark(String sourceName, String newName) async {
    final source = getBookmarkByName(sourceName);
    if (source != null) {
      final copy = FilterBookmark(
        name: newName,
        description: source.description,
        expression: source.expression,
        sorts: List.from(source.sorts),
      );
      await addBookmark(copy);
    }
  }

  String exportToJson() {
    final jsonList = _bookmarks.map((b) => b.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  Future<void> importFromJson(String jsonString, {bool merge = true}) async {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final imported = jsonList
          .map((json) => FilterBookmark.fromJson(json as Map<String, dynamic>))
          .toList();

      if (merge) {
        // Merge: add new bookmarks, update existing ones by name
        for (final bookmark in imported) {
          _bookmarks.removeWhere((b) => b.name == bookmark.name);
          _bookmarks.add(bookmark);
        }
      } else {
        // Replace: completely replace current bookmarks
        _bookmarks = imported;
      }

      _bookmarks.sort((a, b) => a.name.compareTo(b.name));
      await _saveBookmarks();
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to import bookmarks: $e');
    }
  }
}
