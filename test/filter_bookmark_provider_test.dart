import 'package:flutter_test/flutter_test.dart';
import 'package:jules_client/services/filter_bookmark_provider.dart';
import 'package:jules_client/models/filter_bookmark.dart';
import 'package:jules_client/models/search_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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

    // Default bookmarks setup
    const defaultBookmarksJson = '''
    [
      {
        "name": "Default View",
        "filters": [],
        "sorts": [
          {"field": "updated", "direction": "descending"}
        ]
      }
    ]
    ''';

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Mock asset bundle
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'loadString') {
            return const StandardMethodCodec()
                .encodeSuccessEnvelope(defaultBookmarksJson);
          }
          return null;
        },
      );

      provider = FilterBookmarkProvider();
      // Allow the provider to initialize
      await Future.delayed(Duration.zero);
    });

    test('initializes with default bookmarks when none are saved', () async {
      expect(provider.isLoading, isFalse);
      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'Default View');
    });

    test('loads saved bookmarks from SharedPreferences', () async {
      // Save a bookmark to mock prefs
      final bookmarksToSave = [bookmark1];
      final jsonString =
          jsonEncode(bookmarksToSave.map((b) => b.toJson()).toList());
      await prefs.setString('filter_bookmarks_v1', jsonString);

      // Re-initialize provider to load from prefs
      provider = FilterBookmarkProvider();
      await Future.delayed(Duration.zero);

      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'Test Bookmark 1');
    });

    test('addBookmark adds a new bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      expect(provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'), isTrue);

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
      expect(provider.bookmarks.length, 2); // Default + updated
      final result = provider.bookmarks
          .firstWhere((b) => b.name == 'Test Bookmark 1');
      expect(result.filters, isEmpty);
    });

    test('deleteBookmark removes a bookmark and saves', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      expect(provider.bookmarks.length, 3); // Default + 2 added
      await provider.deleteBookmark('Test Bookmark 1');
      expect(provider.bookmarks.length, 2);
      expect(provider.bookmarks.any((b) => b.name == 'Test Bookmark 1'), isFalse);

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.any((b) => b['name'] == 'Test Bookmark 1'), isFalse);
    });

    test('resetToDefaults restores the default bookmarks', () async {
      await provider.addBookmark(bookmark1);
      await provider.addBookmark(bookmark2);

      await provider.resetToDefaults();
      expect(provider.bookmarks.length, 1);
      expect(provider.bookmarks.first.name, 'Default View');

      final savedJson = prefs.getString('filter_bookmarks_v1');
      final List<dynamic> savedList = jsonDecode(savedJson!);
      expect(savedList.length, 1);
      expect(savedList.first['name'], 'Default View');
    });
  });
}
