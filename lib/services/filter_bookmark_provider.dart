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
    _init();
  }

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
      _defaultBookmarks
          .addAll(jsonList.map((json) => FilterBookmark.fromJson(json)));
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

  Future<void> resetToDefaults() async {
    _bookmarks = List.from(_defaultBookmarks);
    await _saveBookmarks();
    notifyListeners();
  }
}
