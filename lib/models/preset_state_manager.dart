import 'package:collection/collection.dart';

import 'filter_bookmark.dart';
import 'filter_element.dart';
import '../services/filter_bookmark_provider.dart';

class PresetStateManager {
  FilterBookmark? _lastLoadedBookmark;

  FilterBookmark? get lastLoadedBookmark => _lastLoadedBookmark;

  void setLastLoadedBookmark(FilterBookmark bookmark) {
    _lastLoadedBookmark = bookmark;
  }

  void clearLastLoadedBookmark() {
    _lastLoadedBookmark = null;
  }

  void onFilterChanged(FilterElement? filterTree) {
    if (_lastLoadedBookmark != null &&
        filterTree?.toExpression() != _lastLoadedBookmark!.expression) {
      if (filterTree?.toExpression().isEmpty ?? true) {
        clearLastLoadedBookmark();
      }
    }
  }

  bool shouldPreFill(
    FilterElement? filterTree,
    List<SortOption> activeSorts,
    FilterBookmarkProvider bookmarkProvider,
  ) {
    if (_lastLoadedBookmark == null) {
      return false;
    }
    if (bookmarkProvider.isSystemBookmark(_lastLoadedBookmark!.name)) {
      return false;
    }
    final isModified = (_lastLoadedBookmark!.expression !=
            (filterTree?.toExpression() ?? '')) ||
        !const SetEquality()
            .equals(_lastLoadedBookmark!.sorts.toSet(), activeSorts.toSet());
    return isModified;
  }
}
