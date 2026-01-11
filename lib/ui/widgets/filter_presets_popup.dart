import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/filter_bookmark.dart';
import '../../services/filter_bookmark_provider.dart';
import '../screens/bookmark_manager_screen.dart';
import '../../models/search_filter.dart';

class FilterPresetsPopup extends StatelessWidget {
  final Function(FilterBookmark) onPresetApplied;
  final VoidCallback onSaveCurrent;
  final List<FilterToken> availableSuggestions;

  const FilterPresetsPopup({
    super.key,
    required this.onPresetApplied,
    required this.onSaveCurrent,
    required this.availableSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterBookmarkProvider>(
      builder: (context, bookmarkProvider, child) {
        if (bookmarkProvider.isLoading) {
          return const IconButton(
            icon: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            onPressed: null,
          );
        }

        return PopupMenuButton<dynamic>(
          icon: const Icon(Icons.bookmarks_outlined),
          tooltip: 'Filter Presets',
          onSelected: (value) {
            if (value is FilterBookmark) {
              onPresetApplied(value);
            } else if (value == 'save_current') {
              onSaveCurrent();
            } else if (value == 'manage') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BookmarkManagerScreen(
                    availableSuggestions: availableSuggestions,
                  ),
                ),
              );
            }
          },
          itemBuilder: (BuildContext context) {
            return [
              ...bookmarkProvider.bookmarks.map((bookmark) {
                final isSystem =
                    bookmarkProvider.isSystemBookmark(bookmark.name);
                return PopupMenuItem<FilterBookmark>(
                  value: bookmark,
                  child: Tooltip(
                    message: '${bookmark.description ?? ''}\n'
                        'Expression: ${bookmark.expression}',
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark,
                          size: 16,
                          color: isSystem ? Colors.blue : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bookmark.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'save_current',
                child: Row(
                  children: [
                    const Icon(Icons.save, size: 16),
                    const SizedBox(width: 8),
                    const Text('Save Current', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 16),
                    const SizedBox(width: 8),
                    const Text('Manage', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ];
          },
        );
      },
    );
  }
}
