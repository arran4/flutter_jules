import 'package:flutter_test/flutter_test.dart';
import 'package:jules_client/services/filter_bookmark_provider.dart';
import 'package:jules_client/models/filter_bookmark.dart';
import 'package:jules_client/models/search_filter.dart';
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
            id: 'flag:new', type: FilterType.flag, label: 'New', value: 'new')
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
      final jsonString =
          jsonEncode(bookmarksToSave.map((b) => b.toJson()).toList());
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
          provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'), isTrue);

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
      final result =
          provider.bookmarks.firstWhere((b) => b.name == 'Test Bookmark 1');
      expect(result.filters, isEmpty);
    });

    test('deleteBookmark removes a bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      expect(provider.bookmarks.length, 2); // 2 added
      await provider.deleteBookmark('Test Bookmark 1');
      expect(provider.bookmarks.length, 1);
      expect(
          provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'), isFalse);

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.any((b) => b['name'] == 'Test Bookmark 1'), isFalse);
    });

    test('resetToDefaults restores the default bookmarks', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      await provider.resetToDefaults();
      expect(provider.bookmarks.length, 0); // Empty defaults in test

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.length, 0);
    });
  });
}
