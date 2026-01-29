import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/filter_bookmark_provider.dart';
import '../../models/filter_bookmark.dart';
import '../../models/search_filter.dart';
import '../../models/session.dart';
import '../../services/session_provider.dart';
import '../../services/message_queue_provider.dart';
import '../../utils/filter_utils.dart';
import '../widgets/advanced_search_bar.dart';
import '../../models/filter_element.dart';
import '../../models/filter_element_builder.dart';
import '../../models/enums.dart';

class BookmarkManagerScreen extends StatefulWidget {
  final List<FilterToken> availableSuggestions;

  const BookmarkManagerScreen({super.key, required this.availableSuggestions});

  @override
  State<BookmarkManagerScreen> createState() => _BookmarkManagerScreenState();
}

class _BookmarkManagerScreenState extends State<BookmarkManagerScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Filter Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _importBookmarks(context),
            tooltip: 'Import from File/Clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportBookmarks(context),
            tooltip: 'Export All to Clipboard/File',
          ),
        ],
      ),
      body: Consumer<FilterBookmarkProvider>(
        builder: (context, provider, child) {
          // 1. Active Bookmarks
          final activeBookmarks = provider.bookmarks.where((b) {
            if (_searchQuery.isEmpty) return true;
            return b.name.toLowerCase().contains(_searchQuery) ||
                (b.description?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          // 2. Restorable System Bookmarks
          final restorableBookmarks = provider
              .getRestorableSystemBookmarks()
              .where((b) {
                if (_searchQuery.isEmpty) return true;
                return b.name.toLowerCase().contains(_searchQuery);
              })
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search presets...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ..._buildActiveSection(context, provider, activeBookmarks),
                    ..._buildRestorableSection(
                      context,
                      provider,
                      restorableBookmarks,
                    ),
                    if (activeBookmarks.isEmpty && restorableBookmarks.isEmpty)
                      _buildEmptyState(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewBookmark(context),
        tooltip: 'Create New Preset',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActiveTile(
    BuildContext context,
    FilterBookmarkProvider provider,
    FilterBookmark bookmark,
  ) {
    final isSystem = provider.isSystemBookmark(bookmark.name);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          isSystem ? Icons.stars : Icons.bookmark,
          color: isSystem ? Colors.amber : Colors.blue,
        ),
        title: Text(
          bookmark.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bookmark.description != null)
              Text(
                bookmark.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (bookmark.expression.isNotEmpty)
              _ExpressionPreviewText(expression: bookmark.expression),
          ],
        ),
        onTap: () => _showBookmarkEditor(context, bookmark),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyBookmark(context, bookmark),
              tooltip: 'Copy',
            ),
            IconButton(
              icon: const Icon(Icons.file_download_outlined, size: 20),
              onPressed: () => _exportSingleBookmark(context, bookmark),
              tooltip: 'Export',
            ),
            if (!isSystem)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showBookmarkEditor(context, bookmark),
                tooltip: 'Edit',
              ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteBookmark(context, bookmark),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveSection(
    BuildContext context,
    FilterBookmarkProvider provider,
    List<FilterBookmark> activeBookmarks,
  ) {
    if (activeBookmarks.isEmpty) {
      return [];
    }

    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          'Active Presets',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      ...activeBookmarks.map((bookmark) {
        return _buildActiveTile(context, provider, bookmark);
      }),
    ];
  }

  Widget _buildRestorableTile(
    BuildContext context,
    FilterBookmarkProvider provider,
    FilterBookmark bookmark,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
      child: ListTile(
        leading: const Icon(Icons.restore_from_trash, color: Colors.grey),
        title: Text(bookmark.name, style: const TextStyle(color: Colors.grey)),
        subtitle: const Text("Deleted (System Preset)"),
        trailing: FilledButton.icon(
          label: const Text("Restore"),
          icon: const Icon(Icons.refresh, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await provider.restoreSystemBookmark(bookmark.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Restored "${bookmark.name}"')),
              );
            }
          },
        ),
      ),
    );
  }

  List<Widget> _buildRestorableSection(
    BuildContext context,
    FilterBookmarkProvider provider,
    List<FilterBookmark> restorableBookmarks,
  ) {
    if (restorableBookmarks.isEmpty) {
      return [];
    }

    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          'Deleted System Presets',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
      ...restorableBookmarks.map((bookmark) {
        return _buildRestorableTile(context, provider, bookmark);
      }),
    ];
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'No presets found.'
              : 'No presets match your search.',
          style: TextStyle(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _createNewBookmark(BuildContext context) {
    _showBookmarkEditor(context, null);
  }

  void _showBookmarkEditor(BuildContext context, FilterBookmark? existing) {
    final isSystem =
        existing != null &&
        context.read<FilterBookmarkProvider>().isSystemBookmark(existing.name);

    showDialog(
      context: context,
      builder: (dialogContext) => _BookmarkEditorDialog(
        existing: existing,
        isReadOnly: isSystem,
        availableSuggestions: widget.availableSuggestions,
      ),
    );
  }

  void _deleteBookmark(BuildContext context, FilterBookmark bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Are you sure you want to delete "${bookmark.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<FilterBookmarkProvider>().deleteBookmark(
                bookmark.name,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "${bookmark.name}" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copyBookmark(BuildContext context, FilterBookmark bookmark) {
    final nameController = TextEditingController(
      text: '${bookmark.name} (Copy)',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Preset'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New Preset Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await context.read<FilterBookmarkProvider>().copyBookmark(
                  bookmark.name,
                  newName,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Preset "$newName" created')),
                  );
                }
              }
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _exportSingleBookmark(BuildContext context, FilterBookmark bookmark) {
    final jsonList = [bookmark.toJson()];
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
    _showExportDialog(context, jsonString, title: 'Export "${bookmark.name}"');
  }

  void _exportBookmarks(BuildContext context) {
    final provider = context.read<FilterBookmarkProvider>();
    final jsonString = provider.exportToJson();
    _showExportDialog(context, jsonString, title: 'Export All Presets');
  }

  void _showExportDialog(
    BuildContext context,
    String jsonString, {
    required String title,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Copy to clipboard or save to file:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _importBookmarks(BuildContext context) {
    final controller = TextEditingController();
    bool merge = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Presets'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste JSON data from clipboard or file:'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Paste JSON here...',
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: merge,
                      onChanged: (value) => setState(() => merge = value!),
                    ),
                    const Expanded(
                      child: Text(
                        'Merge with existing presets (uncheck to replace all)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final jsonString = controller.text.trim();
                if (jsonString.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please paste JSON data')),
                  );
                  return;
                }

                try {
                  await context.read<FilterBookmarkProvider>().importFromJson(
                    jsonString,
                    merge: merge,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            merge
                                ? 'Presets imported and merged!'
                                : 'Presets imported (replaced all)!',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressionPreviewText extends StatelessWidget {
  final String expression;

  const _ExpressionPreviewText({required this.expression});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        expression,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[500],
          fontFamily: 'monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BookmarkEditorDialog extends StatefulWidget {
  final FilterBookmark? existing;
  final bool isReadOnly;
  final List<FilterToken> availableSuggestions;

  const _BookmarkEditorDialog({
    required this.existing,
    required this.isReadOnly,
    required this.availableSuggestions,
  });

  @override
  State<_BookmarkEditorDialog> createState() => _BookmarkEditorDialogState();
}

class _BookmarkEditorDialogState extends State<_BookmarkEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  FilterElement? _filterTree;
  late List<SortOption> _sorts;
  List<Session> _matchingSessions = [];
  int _totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _filterTree = widget.existing?.tree;
    _sorts = List.from(widget.existing?.sorts ?? []);

    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
  }

  void _updatePreview() {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final queueProvider = Provider.of<MessageQueueProvider>(
      context,
      listen: false,
    );

    // Apply filters
    final filters = FilterElementBuilder.toFilterTokens(_filterTree);
    final allMatches = sessionProvider.items
        .where((item) {
          return FilterUtils.matches(
            item.data,
            item.metadata,
            filters,
            queueProvider,
          );
        })
        .map((item) => item.data)
        .toList();

    _totalMatches = allMatches.length;

    // Limit to 50 for preview
    final topMatches = allMatches.take(50).toList();

    setState(() {
      _matchingSessions = topMatches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isReadOnly
            ? 'Preset Details (Read-Only)'
            : (widget.existing == null ? 'New Preset' : 'Edit Preset'),
      ),
      content: SizedBox(
        width: 600,
        height: 600,
        child: Column(
          children: [
            if (!widget.isReadOnly) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Preset Name*',
                  border: OutlineInputBorder(),
                ),
                enabled: !widget.isReadOnly,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                enabled: !widget.isReadOnly,
              ),
            ] else ...[
              ListTile(
                title: const Text("Name"),
                subtitle: Text(widget.existing?.name ?? ''),
              ),
              ListTile(
                title: const Text("Description"),
                subtitle: Text(
                  widget.existing?.description ?? 'No description',
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Filters & Sorting:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: widget.isReadOnly,
              child: Opacity(
                opacity: widget.isReadOnly ? 0.7 : 1.0,
                child: AdvancedSearchBar(
                  filterTree: _filterTree,
                  onFilterTreeChanged: (tree) {
                    setState(() => _filterTree = tree);
                    _updatePreview();
                  },
                  searchText: '',
                  onSearchChanged: (_) {},
                  availableSuggestions: widget.availableSuggestions,
                  activeSorts: _sorts,
                  onSortsChanged: (s) {
                    setState(() => _sorts = s);
                    _updatePreview();
                  },
                  showBookmarksButton: false,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview Matches',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_totalMatches sessions found${_totalMatches > 50 ? ' (showing top 50)' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            Expanded(
              child: _matchingSessions.isEmpty
                  ? const Center(
                      child: Text("No matches found for these filters."),
                    )
                  : ListView.builder(
                      itemCount: _matchingSessions.length,
                      itemBuilder: (context, index) {
                        final s = _matchingSessions[index];
                        return _SessionStatusTile(session: s);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!widget.isReadOnly)
          FilledButton.icon(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final provider = context.read<FilterBookmarkProvider>();
              final newBookmark = FilterBookmark(
                name: name,
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                expression: _filterTree?.toExpression() ?? '',
                sorts: _sorts,
              );

              if (widget.existing == null) {
                provider.addBookmark(newBookmark);
              } else {
                provider.updateBookmark(widget.existing!.name, newBookmark);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Preset "$name" saved')));
            },
            label: const Text('Save Preset'),
            icon: const Icon(Icons.save),
          ),
      ],
    );
  }
}

class _SessionStatusTile extends StatelessWidget {
  final Session session;

  const _SessionStatusTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final state = session.state ?? SessionState.STATE_UNSPECIFIED;
    final statusColor = _resolveStatusColor(state);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
      ),
      title: Text(
        session.title ?? session.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      subtitle: Row(
        children: [
          Text(state.displayName, style: const TextStyle(fontSize: 11)),
          if (session.updateTime != null) ...[
            const SizedBox(width: 8),
            const Text("•", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 8),
            Text(
              DateFormat(
                'MM/dd HH:mm',
              ).format(DateTime.parse(session.updateTime!).toLocal()),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Color _resolveStatusColor(SessionState state) {
    switch (state) {
      case SessionState.COMPLETED:
        return Colors.green;
      case SessionState.FAILED:
        return Colors.red;
      case SessionState.IN_PROGRESS:
        return Colors.blue;
      case SessionState.QUEUED:
        return Colors.amber;
      case SessionState.PLANNING:
        return Colors.deepPurple;
      case SessionState.AWAITING_PLAN_APPROVAL:
        return Colors.orange;
      case SessionState.AWAITING_USER_FEEDBACK:
        return Colors.cyan;
      case SessionState.PAUSED:
        return Colors.brown;
      case SessionState.STATE_UNSPECIFIED:
        return Colors.grey;
    }
  }
}
