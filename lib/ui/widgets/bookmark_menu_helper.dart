// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filter_element.dart';
import '../../models/search_filter.dart';
import '../../models/filter_bookmark.dart';
import '../../services/filter_bookmark_provider.dart';
import '../screens/bookmark_manager_screen.dart';

/// Helper class for managing filter bookmark menu operations
class BookmarkMenuHelper {
  static Future<void> manageBookmarks(
    BuildContext context,
    List<FilterToken> availableSuggestions,
  ) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            BookmarkManagerScreen(availableSuggestions: availableSuggestions),
      ),
    );
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
      expression: currentFilterTree?.toExpression() ?? '',
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

