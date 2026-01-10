import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filter_element.dart';
import '../../models/search_filter.dart';
import '../../models/filter_bookmark.dart';
import '../../services/filter_bookmark_provider.dart';
import '../screens/bookmark_manager_screen.dart';

/// Helper class for managing filter bookmark menu operations
class BookmarkMenuHelper {
  /// Shows the bookmarks menu and handles selection
  static Future<void> showBookmarksMenu({
    required BuildContext context,
    required FilterElement? currentFilterTree,
    required List<SortOption> currentSorts,
    required Function(FilterElement?) onFilterTreeChanged,
    required Function(List<SortOption>) onSortsChanged,
    required List<FilterToken> availableSuggestions,
  }) async {
    // Access the provider
    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );

    // Ensure bookmarks are loaded before showing menu
    if (bookmarkProvider.isLoading) {
      // Show a loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading presets...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );

      // Wait for initialization to complete
      await bookmarkProvider.initialized;
    }

    if (!context.mounted) return;

    // Get the button's position for the menu
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<_BookmarkAction>(
      context: context,
      position: position,
      items: [
        // Header
        const PopupMenuItem(
          enabled: false,
          child: Text(
            'Filter Presets',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const PopupMenuDivider(),

        // Saved bookmarks
        ...bookmarkProvider.bookmarks.map((bookmark) {
          return PopupMenuItem<_BookmarkAction>(
            value: _BookmarkAction.apply(bookmark),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark,
                  size: 18,
                  color: bookmarkProvider.isSystemBookmark(bookmark.name)
                      ? Colors.blue
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bookmark.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (bookmark.description != null &&
                          bookmark.description!.isNotEmpty)
                        Text(
                          bookmark.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const PopupMenuDivider(),

        // Actions
        const PopupMenuItem<_BookmarkAction>(
          value: _BookmarkAction.save,
          child: Row(
            children: [
              Icon(Icons.save, size: 18),
              SizedBox(width: 8),
              Text('Save Current Filters'),
            ],
          ),
        ),
        const PopupMenuItem<_BookmarkAction>(
          value: _BookmarkAction.manage,
          child: Row(
            children: [
              Icon(Icons.settings, size: 18),
              SizedBox(width: 8),
              Text('Manage Presets'),
            ],
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) return;

    if (action.type == _BookmarkActionType.apply) {
      // Apply bookmark
      onFilterTreeChanged(action.bookmark!.tree);
      onSortsChanged(action.bookmark!.sorts);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied preset: ${action.bookmark!.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (action.type == _BookmarkActionType.save) {
      saveCurrentFilters(
        context: context,
        currentFilterTree: currentFilterTree,
        currentSorts: currentSorts,
      );
    } else if (action.type == _BookmarkActionType.manage) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookmarkManagerScreen(
            availableSuggestions: availableSuggestions,
          ),
        ),
      );
    }
  }

  /// Shows a dialog to save the current filters as a bookmark
  static Future<void> saveCurrentFilters({
    required BuildContext context,
    required FilterElement? currentFilterTree,
    required List<SortOption> currentSorts,
  }) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Filter Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g., "My Active Tasks"',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of this preset',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;
    if (!context.mounted) return;

    final name = nameController.text.trim();
    final description = descController.text.trim();

    final bookmark = FilterBookmark(
      name: name,
      description: description.isNotEmpty ? description : null,
      filterTree: currentFilterTree,
      sorts: currentSorts,
    );

    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );

    await bookmarkProvider.addBookmark(bookmark);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved preset: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Internal helper class for menu actions
enum _BookmarkActionType { apply, save, manage }

class _BookmarkAction {
  final _BookmarkActionType type;
  final FilterBookmark? bookmark;

  const _BookmarkAction(this.type, [this.bookmark]);

  factory _BookmarkAction.apply(FilterBookmark bookmark) =>
      _BookmarkAction(_BookmarkActionType.apply, bookmark);
  static const save = _BookmarkAction(_BookmarkActionType.save);
  static const manage = _BookmarkAction(_BookmarkActionType.manage);
}
