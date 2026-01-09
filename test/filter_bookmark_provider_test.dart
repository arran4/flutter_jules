import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/services/filter_bookmark_provider.dart';
import 'package:flutter_jules/models/filter_bookmark.dart';
import 'package:flutter_jules/models/search_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  group('FilterBookmarkProvider', () {
    late FilterBookmarkProvider provider;
    late SharedPreferences prefs;

    // Sample bookmark for testing
    final bookmark1 = FilterBookmark(
      name: 'Test Bookmark 1',
      filters: [
        const FilterToken(
          id: 'flag:new',
          type: FilterType.flag,
          label: 'New',
          value: 'new',
        ),
      ],
      sorts: [const SortOption(SortField.updated, SortDirection.descending)],
    );

    final bookmark2 = FilterBookmark(
      name: 'Test Bookmark 2',
      filters: [],
      sorts: [],
    );

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Note: We can't easily mock rootBundle.loadString in these tests,
      // so we'll just test with empty defaults and rely on SharedPreferences

      provider = FilterBookmarkProvider();
      // Allow the provider to initialize
      await provider.initialized;
    });

    test('initializes with empty bookmarks when none are saved', () async {
      expect(provider.isLoading, isFalse);
      expect(provider.bookmarks.length, 0);
    });

    test('loads saved bookmarks from SharedPreferences', () async {
      // Save a bookmark to mock prefs
      final bookmarksToSave = [bookmark1];
      final jsonString = jsonEncode(
        bookmarksToSave.map((b) => b.toJson()).toList(),
      );
      await prefs.setString('filter_bookmarks_v1', jsonString);

      // Re-initialize provider to load from prefs
      provider = FilterBookmarkProvider();
      await provider.initialized;

      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'Test Bookmark 1');
    });

    test('addBookmark adds a new bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      expect(
        provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'),
        isTrue,
      );

      final savedJson = prefs.getString('filter_bookmarks_v1');
      expect(savedJson, isNotNull);
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.any((b) => b['name'] == 'Test Bookmark 1'), isTrue);
    });

    test('addBookmark updates an existing bookmark', () async {
      await provider.addBookmark(bookmark1);
      final updatedBookmark = FilterBookmark(
        name: 'Test Bookmark 1', // Same name
        filters: [], // Different filters
        sorts: [],
      );

      await provider.addBookmark(updatedBookmark);
      expect(provider.bookmarks.length, 1); // Just the updated one
      final result = provider.bookmarks.firstWhere(
        (b) => b.name == 'Test Bookmark 1',
      );
      expect(result.filters, isEmpty);
    });

    test('deleteBookmark removes a bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      expect(provider.bookmarks.length, 2); // 2 added
      await provider.deleteBookmark('Test Bookmark 1');
      expect(provider.bookmarks.length, 1);
      expect(
        provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'),
        isFalse,
      );

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.any((b) => b['name'] == 'Test Bookmark 1'), isFalse);
    });

    test('validates export and import functionality', () async {
      // Setup: Add bookmarks and export
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);
      final jsonExport = provider.exportToJson();

      // Verify export is valid JSON
      final List<dynamic> decoded = jsonDecode(jsonExport);
      expect(decoded.length, 2);

      // Reset and Import
      await prefs.clear();
      provider = FilterBookmarkProvider();
      await provider.initialized;

      expect(provider.bookmarks.isEmpty, isTrue);

      await provider.importFromJson(jsonExport, merge: false);
      expect(provider.bookmarks.length, 2);
      expect(provider.bookmarks.any((b) => b.name == bookmark1.name), isTrue);
      expect(provider.bookmarks.any((b) => b.name == bookmark2.name), isTrue);
    });

    test('importFromJson merges correctly', () async {
      await provider.addBookmark(bookmark1);

      // Prepare import data: Modified bookmark1, New bookmark2
      final modifiedBookmark1 = FilterBookmark(
        name: bookmark1.name,
        filters: [], // Changed
        sorts: [],
      );
      final listToImport = [modifiedBookmark1, bookmark2];
      final jsonImport = jsonEncode(
        listToImport.map((b) => b.toJson()).toList(),
      );

      // Import with merge=true
      await provider.importFromJson(jsonImport, merge: true);

      expect(provider.bookmarks.length, 2);

      // Verify bookmark1 was updated
      final b1 = provider.bookmarks.firstWhere((b) => b.name == bookmark1.name);
      expect(b1.filters, isEmpty);

      // Verify bookmark2 was added
      expect(provider.bookmarks.any((b) => b.name == bookmark2.name), isTrue);
    });

    test('updateBookmark updates correctly', () async {
      await provider.addBookmark(bookmark1);

      final updated = FilterBookmark(
        name: 'New Name',
        filters: bookmark1.filters,
        sorts: bookmark1.sorts,
      );

      // Note: provider.updateBookmark takes oldName to find it.
      // But currently implementation replaces at index.
      // If we change name, we need to be careful.
      // The implementation: _bookmarks[index] = newBookmark;
      // So checking logic...

      await provider.updateBookmark(bookmark1.name, updated);

      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'New Name');
      expect(provider.bookmarks.any((b) => b.name == bookmark1.name), isFalse);
    });

    test('copyBookmark creates a copy', () async {
      await provider.addBookmark(bookmark1);

      await provider.copyBookmark(bookmark1.name, 'Copy of Bookmark 1');

      expect(provider.bookmarks.length, 2);
      final copy = provider.bookmarks.firstWhere(
        (b) => b.name == 'Copy of Bookmark 1',
      );
      expect(copy.description, bookmark1.description);
      // Ensure specific fields match
      expect(copy.filters.length, bookmark1.filters.length);
    });
  });
}
