import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/filter_element.dart';
import '../../models/filter_element_builder.dart';
import '../../models/search_filter.dart';
import 'filter_element_widget.dart';
import 'sort_pills_widget.dart';
import 'bookmark_menu_helper.dart';

/// Refactored search bar using hierarchical FilterElement structure.
/// Replaces the old flat-list based AdvancedSearchBar.
class AdvancedSearchBar extends StatefulWidget {
  // Hierarchical filter interface
  final FilterElement? filterTree;
  final ValueChanged<FilterElement?> onFilterTreeChanged;

  // Search text (kept separate from filter tree)
  final String searchText;
  final ValueChanged<String> onSearchChanged;

  final List<FilterToken>
      availableSuggestions; // All possible filters for autocomplete
  final VoidCallback? onOpenFilterMenu;

  final List<SortOption> activeSorts;
  final ValueChanged<List<SortOption>> onSortsChanged;
  final bool showBookmarksButton;

  const AdvancedSearchBar({
    super.key,
    required this.filterTree,
    required this.onFilterTreeChanged,
    required this.searchText,
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
    _textController.text = widget.searchText;
    _focusNode = FocusNode(onKeyEvent: _handleFocusKey);
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_focusNode.hasFocus) {
            _removeOverlay();
          }
        });
      }
    });
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
    widget.onSearchChanged(text);

    // Check for @ symbol for filter autocomplete
    final atIndex = text.lastIndexOf('@');
    if (atIndex != -1 && atIndex < text.length) {
      _tryCommitFilter(text, atIndex);
    } else {
      _removeOverlay();
    }
  }

  void _tryCommitFilter(String text, int atIndex) {
    final query = text.substring(atIndex + 1).toLowerCase();

    if (query.isEmpty) {
      _filteredSuggestions = widget.availableSuggestions;
    } else {
      _filteredSuggestions = widget.availableSuggestions.where((s) {
        return s.label.toLowerCase().contains(query) ||
            s.id.toLowerCase().contains(query);
      }).toList();
    }

    _highlightedIndex = 0;

    if (_filteredSuggestions.isNotEmpty) {
      _showOverlay();
    } else {
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
        });
        _showOverlay();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _highlightedIndex = (_highlightedIndex - 1) < 0
              ? _filteredSuggestions.length - 1
              : _highlightedIndex - 1;
        });
        _showOverlay();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (_highlightedIndex < _filteredSuggestions.length) {
          _selectSuggestion(_filteredSuggestions[_highlightedIndex]);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _filteredSuggestions[index];
                  final isHighlighted = index == _highlightedIndex;

                  return InkWell(
                    onTap: () => _selectSuggestion(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? Colors.blue.shade50
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getIconForType(suggestion.type),
                            size: 16,
                            color: _getColorForType(suggestion.type),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
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
    // Convert token to FilterElement
    FilterElement? newElement;

    switch (token.type) {
      case FilterType.flag:
        if (token.value.toString() == 'has_pr' || token.id == 'flag:has_pr') {
          newElement = HasPrElement();
        } else {
          newElement = LabelElement(token.label, token.value.toString());
        }
        break;
      case FilterType.status:
        newElement = StatusElement(token.label, token.value.toString());
        break;
      case FilterType.source:
        newElement = SourceElement(token.label, token.value.toString());
        break;
      case FilterType.text:
        // Text search is handled separately, not in tree
        return;
    }

    // Handle exclude mode
    if (token.mode == FilterMode.exclude) {
      newElement = NotElement(newElement);
    }

    // Add to tree using smart builder
    final newTree =
        FilterElementBuilder.addFilter(widget.filterTree, newElement);
    widget.onFilterTreeChanged(newTree);

    // Clear the @part from text
    final text = _textController.text;
    int atIndex = text.lastIndexOf('@');
    if (atIndex != -1) {
      _textController.text = text.substring(0, atIndex);
    } else {
      _textController.clear();
    }

    widget.onSearchChanged(_textController.text);

    _removeOverlay();
    _focusNode.requestFocus();
  }

  IconData _getIconForType(FilterType type) {
    switch (type) {
      case FilterType.flag:
        return Icons.flag;
      case FilterType.status:
        return Icons.info_outline;
      case FilterType.source:
        return Icons.source;
      case FilterType.text:
        return Icons.text_fields;
    }
  }

  Color _getColorForType(FilterType type) {
    switch (type) {
      case FilterType.flag:
        return Colors.green;
      case FilterType.status:
        return Colors.blue;
      case FilterType.source:
        return Colors.purple;
      case FilterType.text:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search field and action buttons
            Row(
              children: [
                // Search input
                Expanded(
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          final element = TextElement(value.trim());
                          final newTree = FilterElementBuilder.addFilter(
                              widget.filterTree, element);
                          widget.onFilterTreeChanged(newTree);
                          _textController.clear();
                          widget.onSearchChanged('');
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Search... (type @ for filters)',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _textController.clear();
                                  widget.onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Filter menu button
                if (widget.onOpenFilterMenu != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_outlined),
                    onPressed: widget.onOpenFilterMenu,
                    tooltip: 'Show Filter Options',
                  ),

                // Bookmarks button
                if (widget.showBookmarksButton)
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.bookmarks_outlined),
                      onPressed: () => BookmarkMenuHelper.showBookmarksMenu(
                        context: context,
                        currentFilterTree: widget.filterTree,
                        currentSorts: widget.activeSorts,
                        onFilterTreeChanged: widget.onFilterTreeChanged,
                        onSortsChanged: widget.onSortsChanged,
                        availableSuggestions: widget.availableSuggestions,
                      ),
                      tooltip: 'Filter Presets',
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Active filters display
            if (widget.filterTree != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilterElementWidget(
                  element: widget.filterTree,
                  onRemove: (element) {
                    final newTree = FilterElementBuilder.removeFilter(
                      widget.filterTree,
                      element,
                    );
                    final simplified = FilterElementBuilder.simplify(newTree);
                    widget.onFilterTreeChanged(simplified);
                  },
                  onToggleNot: (element) {
                    final newTree = FilterElementBuilder.toggleNot(
                      widget.filterTree!,
                      element,
                    );
                    widget.onFilterTreeChanged(newTree);
                  },
                  onTap: null, // Can add menu later
                ),
              ),

            // Sort pills
            if (widget.activeSorts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SortPillsWidget(
                  activeSorts: widget.activeSorts,
                  onSortsChanged: widget.onSortsChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
