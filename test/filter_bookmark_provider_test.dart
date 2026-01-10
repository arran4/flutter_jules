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
      expression: 'New()',
      sorts: [const SortOption(SortField.updated, SortDirection.descending)],
    );

    final bookmark2 = FilterBookmark(
      name: 'Test Bookmark 2',
      expression: '',
      sorts: [],
    );

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      provider = FilterBookmarkProvider();
      await provider.initialized;
    });

    test('initializes with empty bookmarks when none are saved', () async {
      expect(provider.isLoading, isFalse);
      expect(provider.bookmarks.length, 0);
    });

    test('loads saved bookmarks from SharedPreferences', () async {
      final bookmarksToSave = [bookmark1];
      final jsonString = jsonEncode(
        bookmarksToSave.map((b) => b.toJson()).toList(),
      );
      await prefs.setString('filter_bookmarks_v1', jsonString);

      provider = FilterBookmarkProvider();
      await provider.initialized;

      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'Test Bookmark 1');
      expect(provider.bookmarks.first.expression, 'New()');
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
      expect(savedList.any((b) => b['expression'] == 'New()'), isTrue);
    });

    test('addBookmark updates an existing bookmark', () async {
      await provider.addBookmark(bookmark1);
      final updatedBookmark = FilterBookmark(
        name: 'Test Bookmark 1',
        expression: 'State(COMPLETED)',
        sorts: [],
      );

      await provider.addBookmark(updatedBookmark);
      expect(provider.bookmarks.length, 1);
      final result = provider.bookmarks.firstWhere(
        (b) => b.name == 'Test Bookmark 1',
      );
      expect(result.expression, 'State(COMPLETED)');
    });

    test('deleteBookmark removes a bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      expect(provider.bookmarks.length, 2);
      await provider.deleteBookmark('Test Bookmark 1');
      expect(provider.bookmarks.length, 1);

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.any((b) => b['name'] == 'Test Bookmark 1'), isFalse);
    });

    test('importFromJson merges correctly', () async {
      await provider.addBookmark(bookmark1);

      final modifiedBookmark1 = FilterBookmark(
        name: bookmark1.name,
        expression: 'Watching()',
        sorts: [],
      );
      final listToImport = [modifiedBookmark1, bookmark2];
      final jsonImport = jsonEncode(
        listToImport.map((b) => b.toJson()).toList(),
      );

      await provider.importFromJson(jsonImport, merge: true);

      expect(provider.bookmarks.length, 2);
      final b1 = provider.bookmarks.firstWhere((b) => b.name == bookmark1.name);
      expect(b1.expression, 'Watching()');
    });

    test('copyBookmark creates a copy', () async {
      await provider.addBookmark(bookmark1);

      await provider.copyBookmark(bookmark1.name, 'Copy of Bookmark 1');

      expect(provider.bookmarks.length, 2);
      final copy = provider.bookmarks.firstWhere(
        (b) => b.name == 'Copy of Bookmark 1',
      );
      expect(copy.expression, bookmark1.expression);
    });
  });
}
