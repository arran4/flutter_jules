import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/models/preset_state_manager.dart';
import 'package:flutter_jules/services/filter_bookmark_provider.dart';
import 'package:flutter_jules/models/filter_bookmark.dart';
import 'package:flutter_jules/models/filter_element.dart';

// Manual mock to avoid build_runner dependency
class MockFilterBookmarkProvider extends Fake implements FilterBookmarkProvider {
  @override
  bool isSystemBookmark(String name) {
    return name.contains('System');
  }
}

void main() {
  late PresetStateManager manager;
  late MockFilterBookmarkProvider mockProvider;

  setUp(() {
    manager = PresetStateManager();
    mockProvider = MockFilterBookmarkProvider();
  });

  group('PresetStateManager', () {
    test('shouldPreFill returns false when no bookmark loaded', () {
      expect(
          manager.shouldPreFill(null, [], mockProvider),
          isFalse);
    });

    test('shouldPreFill returns false for system bookmark', () {
      final bookmark = FilterBookmark(name: 'System Preset', expression: '', sorts: []);
      manager.setLastLoadedBookmark(bookmark);

      expect(
          manager.shouldPreFill(null, [], mockProvider),
          isFalse);
    });

    test('shouldPreFill returns true for unmodified non-system bookmark', () {
      final bookmark = FilterBookmark(name: 'My Preset', expression: '', sorts: []);
      manager.setLastLoadedBookmark(bookmark);

      expect(
          manager.shouldPreFill(null, [], mockProvider),
          isTrue);
    });

    test('shouldPreFill returns true for modified non-system bookmark', () {
      final bookmark = FilterBookmark(name: 'My Preset', expression: 'status:open', sorts: []);
      manager.setLastLoadedBookmark(bookmark);

      // Modified (filterTree is null -> empty expression != 'status:open')
      expect(
          manager.shouldPreFill(null, [], mockProvider),
          isTrue);
    });
  });
}
