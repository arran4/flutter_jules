import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/filter_bookmark.dart';
import 'package:flutter_jules/models/filter_element.dart';
import 'package:flutter_jules/models/preset_state_manager.dart';
import 'package:flutter_jules/models/search_filter.dart';
import 'package:flutter_jules/services/filter_bookmark_provider.dart';

// Fake provider only implementing what's needed for PresetStateManager
class FakeFilterBookmarkProvider extends ChangeNotifier implements FilterBookmarkProvider {
  final Set<String> _systemBookmarks = {};

  void addSystemBookmark(String name) {
    _systemBookmarks.add(name);
  }

  @override
  bool isSystemBookmark(String name) {
    return _systemBookmarks.contains(name);
  }

  // Necessary to satisfy the interface without implementing everything
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PresetStateManager', () {
    late PresetStateManager manager;
    late FakeFilterBookmarkProvider mockProvider;

    setUp(() {
      manager = PresetStateManager();
      mockProvider = FakeFilterBookmarkProvider();
    });

    test('shouldPreFill returns false if no bookmark loaded', () {
      final filter = TextElement('foo');
      expect(manager.shouldPreFill(filter, [], mockProvider), isFalse);
    });

    test('shouldPreFill returns false if system bookmark loaded', () {
      final bookmark = FilterBookmark(
        name: 'System Preset',
        expression: 'foo',
        sorts: [],
      );
      mockProvider.addSystemBookmark('System Preset');

      manager.setLastLoadedBookmark(bookmark);

      final filter = TextElement('foo'); // Not modified
      expect(manager.shouldPreFill(filter, [], mockProvider), isFalse);

      final filterModified = TextElement('bar'); // Modified
      expect(manager.shouldPreFill(filterModified, [], mockProvider), isFalse);
    });

    test('shouldPreFill returns true if custom bookmark modified', () {
      final bookmark = FilterBookmark(
        name: 'Custom Preset',
        expression: 'foo',
        sorts: [],
      );
      // Not added to system bookmarks

      manager.setLastLoadedBookmark(bookmark);

      final filter = TextElement('bar'); // Modified
      expect(manager.shouldPreFill(filter, [], mockProvider), isTrue);
    });

    test('shouldPreFill returns true if custom bookmark NOT modified', () {
      final bookmark = FilterBookmark(
        name: 'Custom Preset',
        expression: 'TEXT(foo)',
        sorts: [],
      );

      manager.setLastLoadedBookmark(bookmark);

      final filter = TextElement('foo');
      // TextElement('foo').toExpression() -> 'TEXT(foo)' matching the bookmark

      expect(manager.shouldPreFill(filter, [], mockProvider), isTrue);
    });

    test('onFilterChanged clears bookmark if expression is empty', () {
      final bookmark = FilterBookmark(
        name: 'Custom Preset',
        expression: 'foo',
        sorts: [],
      );
      manager.setLastLoadedBookmark(bookmark);

      // Pass null to simulate cleared filter
      manager.onFilterChanged(null);

      expect(manager.lastLoadedBookmark, isNull);
    });
  });
}
