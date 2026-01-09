import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/search_filter.dart';
import '../../models/filter_bookmark.dart';
import '../../services/filter_bookmark_provider.dart';
import 'package:flutter/services.dart';
import '../screens/bookmark_manager_screen.dart';

class AdvancedSearchBar extends StatefulWidget {
  final List<FilterToken> activeFilters;
  final ValueChanged<List<FilterToken>> onFiltersChanged;
  final ValueChanged<String> onSearchChanged;
  final List<FilterToken>
  availableSuggestions; // All possible filters for autocomplete
  final VoidCallback? onOpenFilterMenu;

  final List<SortOption> activeSorts;
  final ValueChanged<List<SortOption>> onSortsChanged;
  final bool showBookmarksButton;

  const AdvancedSearchBar({
    super.key,
    required this.activeFilters,
    required this.onFiltersChanged,
    required this.onSearchChanged,
    required this.availableSuggestions,
    required this.onOpenFilterMenu,
    required this.activeSorts,
    required this.onSortsChanged,
    this.showBookmarksButton = true,
  });

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar> {
  final TextEditingController _textController = TextEditingController();
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<FilterToken> _filteredSuggestions = [];
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleFocusKey);
    // Using simple listener for text changes
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Delay removal slightly to allow tap events on overlay to register
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_focusNode.hasFocus) {
            _removeOverlay();
          }
        });
      }
    });
  }

  void _showBookmarksMenu(BuildContext context) {
    // Access the provider
    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );

    // Get the button's position for the menu
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<dynamic>(
      context: context,
      position: position,
      items: <PopupMenuEntry<dynamic>>[
        // List existing bookmarks
        ...bookmarkProvider.bookmarks.map((bookmark) {
          return PopupMenuItem(
            child: Text(bookmark.name),
            onTap: () {
              widget.onFiltersChanged(bookmark.filters);
              widget.onSortsChanged(bookmark.sorts);
            },
          );
        }),
        if (bookmarkProvider.bookmarks.isNotEmpty) const PopupMenuDivider(),

        // Save current filter
        const PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(Icons.save, size: 16),
              SizedBox(width: 8),
              Text("Save current filters..."),
            ],
          ),
        ),

        // Manage bookmarks
        const PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text("Manage presets..."),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'save') {
        _saveCurrentFilters();
      } else if (value == 'manage') {
        _manageBookmarks();
      }
    });
  }

  void _saveCurrentFilters() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Filter Preset'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Preset Name',
            hintText: 'e.g., "My High Priority View"',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final bookmark = FilterBookmark(
                  name: name,
                  filters: widget.activeFilters,
                  sorts: widget.activeSorts,
                );
                Provider.of<FilterBookmarkProvider>(
                  context,
                  listen: false,
                ).addBookmark(bookmark);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Preset "$name" saved.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _manageBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookmarkManagerScreen(
          availableSuggestions: widget.availableSuggestions,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;

    // Check if we are in "filter composition mode"
    // Heuristic: If there's an uncommitted '@'
    int atIndex = text.lastIndexOf('@');
    final isComposingFilter =
        atIndex != -1 && (atIndex == 0 || text[atIndex - 1] == ' ');

    if (isComposingFilter) {
      // We are composing a filter.
      // Check if the last character is a space (indicating commit attempt)
      if (text.endsWith(' ')) {
        _tryCommitFilter(text, atIndex);
        return;
      }

      // Ensure we don't accidentally filter the main list by the partially typed filter tag
      // Only start filtering suggestions
      // For the main search, pass everything BEFORE the @
      final mainSearchText = text.substring(0, atIndex);
      widget.onSearchChanged(mainSearchText);

      final query = text.substring(atIndex + 1).toLowerCase();

      setState(() {
        _filteredSuggestions = widget.availableSuggestions.where((s) {
          if (widget.activeFilters.any(
            (af) => af.id == s.id && af.type == s.type,
          )) {
            return false;
          }
          return s.label.toLowerCase().contains(query);
        }).toList();

        // Highlight first by default
        _highlightedIndex = 0;
      });

      if (_filteredSuggestions.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } else {
      // Normal text search mode
      widget.onSearchChanged(text);
      _removeOverlay();
    }
  }

  void _tryCommitFilter(String text, int atIndex) {
    // User hit space.
    // 1. If we have exact match in filtered suggestions, pick it.
    // 2. If 'highlighted' index is valid, pick it? (Usually space confirms selection? Or just tab/enter?)
    // The user request says "Pressing space doesn't cause the @<thing> to become a pill".
    // So let's try to match.

    final query = text
        .substring(atIndex + 1, text.length - 1)
        .toLowerCase(); // remove space

    if (query.isEmpty) return; // just "@ "

    // Try exact match first
    final exactMatch = widget.availableSuggestions.firstWhere(
      (s) => s.label.toLowerCase() == query,
      orElse: () => const FilterToken(
        id: '',
        type: FilterType.text,
        label: '',
        value: '',
      ),
    );

    if (exactMatch.id.isNotEmpty) {
      _selectSuggestion(exactMatch);
    } else {
      // No match found.
      // Maybe the user wants a literal "@foo" text search?
      // Or maybe they just typed "foo " and expected it to become a pill?
      // If not found, we just leave it as text (standard behavior).
      // But we DO need to update the searchChanged to include the full text now
      widget.onSearchChanged(text);
      _removeOverlay();
    }
  }

  KeyEventResult _handleFocusKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_overlayEntry != null && _filteredSuggestions.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _highlightedIndex =
              (_highlightedIndex + 1) % _filteredSuggestions.length;
          _showOverlay(); // Rebuild to update highlight
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _highlightedIndex =
              (_highlightedIndex - 1 + _filteredSuggestions.length) %
              _filteredSuggestions.length;
          _showOverlay();
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (_filteredSuggestions.isNotEmpty) {
          _selectSuggestion(_filteredSuggestions[_highlightedIndex]);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      // Just rebuild
      _overlayEntry!.markNeedsBuild();
      return;
    }

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            color: Theme.of(context).cardColor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount:
                    _filteredSuggestions.length + 1, // +1 for "Search for @..."
                itemBuilder: (context, index) {
                  if (index == _filteredSuggestions.length) {
                    // "Search for literal..." option
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.search, size: 16),
                      title: const Text("Search text literally..."),
                      onTap: () {
                        _removeOverlay();
                        // Keep text as is, just close overlay
                        widget.onSearchChanged(_textController.text);
                      },
                    );
                  }

                  final suggestion = _filteredSuggestions[index];
                  final isHighlighted = index == _highlightedIndex;

                  return Container(
                    color: isHighlighted
                        ? Theme.of(context).highlightColor
                        : null,
                    child: ListTile(
                      dense: true,
                      leading: _getIconForType(suggestion.type),
                      title: Text(suggestion.label),
                      onTap: () {
                        _selectSuggestion(suggestion);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(FilterToken token) {
    final newFilters = List<FilterToken>.from(widget.activeFilters)..add(token);
    widget.onFiltersChanged(newFilters);

    // Clear the @part from text
    final text = _textController.text;
    int atIndex = text.lastIndexOf('@');
    if (atIndex != -1) {
      _textController.text = text.substring(0, atIndex); // keep text before @
    } else {
      _textController.clear();
    }

    // Update search with cleared text
    widget.onSearchChanged(_textController.text);

    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _removeFilter(FilterToken token) {
    final newFilters = List<FilterToken>.from(widget.activeFilters)
      ..remove(token);
    widget.onFiltersChanged(newFilters);
  }

  void _toggleFilterMode(FilterToken token) {
    final index = widget.activeFilters.indexOf(token);
    if (index != -1) {
      final newFilters = List<FilterToken>.from(widget.activeFilters);
      newFilters[index] = token.toggleMode();
      widget.onFiltersChanged(newFilters);
    }
  }

  Icon _getIconForType(FilterType type) {
    switch (type) {
      case FilterType.status:
        return const Icon(Icons.info_outline, size: 16);
      case FilterType.source:
        return const Icon(Icons.source, size: 16);
      case FilterType.flag:
        return const Icon(Icons.flag, size: 16);
      case FilterType.text:
        return const Icon(Icons.text_fields, size: 16);
    }
  }

  Color _getColorForType(FilterType type) {
    switch (type) {
      case FilterType.status:
        return Colors.blue.shade100;
      case FilterType.source:
        return Colors.purple.shade100;
      case FilterType.flag:
        return Colors.green.shade100;
      case FilterType.text:
        return Colors.grey.shade200;
    }
  }

  void _toggleSortDirection(SortOption sort) {
    final index = widget.activeSorts.indexOf(sort);
    if (index == -1) return;

    final newSorts = List<SortOption>.from(widget.activeSorts);
    final newDirection = sort.direction == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
    newSorts[index] = SortOption(sort.field, newDirection);
    widget.onSortsChanged(newSorts);
  }

  void _removeSort(SortOption sort) {
    final newSorts = List<SortOption>.from(widget.activeSorts)..remove(sort);
    widget.onSortsChanged(newSorts);
  }

  void _reorderSorts(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<SortOption>.from(widget.activeSorts);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    widget.onSortsChanged(items);
  }

  Widget _buildSortPill(SortOption sort, {bool isDragging = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Tooltip(
        message:
            "Sort by ${sort.label}. Tap to toggle direction. Drag to reorder.",
        child: InkWell(
          onTap: () => _toggleSortDirection(sort),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDragging ? Colors.grey.shade300 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: isDragging
                  ? const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sort.label, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 2),
                Icon(
                  sort.direction == SortDirection.descending
                      ? Icons.arrow_drop_down
                      : Icons.arrow_drop_up,
                  size: 16,
                  color: Colors.black54,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _removeSort(sort),
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addSort() {
    // Show menu to pick a field not in list
    final existingFields = widget.activeSorts.map((s) => s.field).toSet();
    final availableFields = SortField.values
        .where((f) => !existingFields.contains(f))
        .toList();

    if (availableFields.isEmpty) return; // All fields added

    // Find the plus button context for position
    // Simple findRenderObject fallback
    final RenderBox? rb = context.findRenderObject() as RenderBox?;
    final offset = rb != null ? rb.localToGlobal(Offset.zero) : Offset.zero;
    final size = rb?.size ?? Size.zero;

    showMenu<SortField>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + size.width - 50,
        offset.dy + size.height,
        0,
        0,
      ),
      items: availableFields
          .map(
            (f) => PopupMenuItem(value: f, child: Text(_getSortFieldLabel(f))),
          )
          .toList(),
    ).then((value) {
      if (value != null) {
        final newSorts = List<SortOption>.from(widget.activeSorts)
          ..add(SortOption(value, SortDirection.descending));
        widget.onSortsChanged(newSorts);
      }
    });
  }

  String _getSortFieldLabel(SortField field) {
    switch (field) {
      case SortField.updated:
        return "Updated";
      case SortField.created:
        return "Created";
      case SortField.name:
        return "Name";
      case SortField.source:
        return "Source"; // Repo
      case SortField.status:
        return "Status";
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filters Rows
            if (widget.activeFilters.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: widget.activeFilters.map((filter) {
                  return InputChip(
                    label: Text(
                      filter.mode == FilterMode.include
                          ? filter.label
                          : "NOT ${filter.label}",
                      style: TextStyle(
                        decoration: filter.mode == FilterMode.exclude
                            ? TextDecoration.lineThrough
                            : null,
                        color: filter.mode == FilterMode.exclude
                            ? Colors.red
                            : Colors.black87,
                      ),
                    ),
                    avatar: _getIconForType(filter.type),
                    backgroundColor: filter.mode == FilterMode.exclude
                        ? Colors.red.shade100
                        : _getColorForType(filter.type),
                    onDeleted: () => _removeFilter(filter),
                    onPressed: () => _toggleFilterMode(filter),
                    tooltip: "Tap to toggle Include/Exclude",
                  );
                }).toList(),
              ),

            // Search Input Row
            Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: const InputDecoration(
                      hintText: 'Search... (Type @ for filters)',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),

                // Active Sorts
                // Active Sorts
                if (widget.activeSorts.isNotEmpty)
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                // Drag target for reordering
                ...widget.activeSorts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sort = entry.value;

                  return Draggable<SortOption>(
                    data: sort,
                    feedback: Material(
                      color: Colors.transparent,
                      child: _buildSortPill(sort, isDragging: true),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: _buildSortPill(sort),
                    ),
                    child: DragTarget<SortOption>(
                      onWillAcceptWithDetails: (details) =>
                          details.data != sort,
                      onAcceptWithDetails: (details) {
                        final incoming = details.data;
                        final incomingIndex = widget.activeSorts.indexOf(
                          incoming,
                        );
                        final targetIndex = index;
                        _reorderSorts(incomingIndex, targetIndex);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Visual indicator for drop
                            if (candidateData.isNotEmpty)
                              Container(
                                width: 4,
                                height: 24,
                                color: Colors.blueAccent,
                              ),
                            _buildSortPill(sort),
                          ],
                        );
                      },
                    ),
                  );
                }),

                // Add Sort Button
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onPressed: _addSort,
                  tooltip: "Add Sort Criteria",
                ),

                const SizedBox(width: 8),
                if (widget.showBookmarksButton)
                  Builder(
                    builder: (buttonContext) => IconButton(
                      icon: const Icon(Icons.bookmarks_outlined),
                      onPressed: () => _showBookmarksMenu(buttonContext),
                      tooltip: "Filter Presets",
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: widget.onOpenFilterMenu,
                  tooltip: "All Filters",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
