import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filter_bookmark.dart';
import '../../services/filter_bookmark_provider.dart';

class FilterPresetsPopup extends StatelessWidget {
  final Function(FilterBookmark) onApplyBookmark;
  final VoidCallback onManageBookmarks;
  final VoidCallback onSaveCurrent;

  const FilterPresetsPopup({
    super.key,
    required this.onApplyBookmark,
    required this.onManageBookmarks,
    required this.onSaveCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(context);
    final bookmarks = bookmarkProvider.bookmarks;
    final systemBookmarks = bookmarks
        .where((b) => bookmarkProvider.isSystemBookmark(b.name))
        .toList();
    final userBookmarks = bookmarks
        .where((b) => !bookmarkProvider.isSystemBookmark(b.name))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (userBookmarks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'My Presets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...userBookmarks.map((bookmark) => _buildBookmarkItem(
                context,
                bookmark,
                isSystem: false,
              )),
          const Divider(),
        ],
        if (systemBookmarks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'System Presets',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...systemBookmarks.map((bookmark) => _buildBookmarkItem(
                context,
                bookmark,
                isSystem: true,
              )),
        ],
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Current'),
              onPressed: () {
                Navigator.pop(context);
                onSaveCurrent();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Manage'),
              onPressed: () {
                Navigator.pop(context);
                onManageBookmarks();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookmarkItem(
    BuildContext context,
    FilterBookmark bookmark, {
    required bool isSystem,
  }) {
    return Tooltip(
      message: bookmark.description ?? '',
      child: ListTile(
        leading: Icon(
          Icons.bookmark,
          color: isSystem ? Colors.blue : Colors.orange,
          size: 20,
        ),
        title: Text(bookmark.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          bookmark.expression,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onTap: () {
          onApplyBookmark(bookmark);
          Navigator.pop(context);
        },
      ),
    );
  }
}
