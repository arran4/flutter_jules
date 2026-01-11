import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/filter_element.dart';
import '../../models/filter_element_builder.dart';
import '../../models/filter_expression_parser.dart';
import '../../models/search_filter.dart';
import 'filter_element_widget.dart';
import 'sort_pills_widget.dart';
import 'bookmark_menu_helper.dart';
import 'time_filter_dialog.dart';

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
    required this.activeSorts,
    required this.onSortsChanged,
    this.showBookmarksButton = true,
  });

  @override
  State<AdvancedSearchBar> createState() => _AdvancedSearchBarState();
}

class _AdvancedSearchBarState extends State<AdvancedSearchBar> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _expressionController = TextEditingController();
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<FilterToken> _filteredSuggestions = [];
  int _highlightedIndex = 0;
  bool _isFilterExpanded = true;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.searchText;
    _expressionController.text = widget.filterTree?.toExpression() ?? '';
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
  void didUpdateWidget(AdvancedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterTree != oldWidget.filterTree) {
      final newExpr = widget.filterTree?.toExpression() ?? '';
      if (_expressionController.text != newExpr) {
        _expressionController.text = newExpr;
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _textController.dispose();
    _expressionController.dispose();
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

    // Group suggestions by type
    final flagSuggestions =
        _filteredSuggestions.where((s) => s.type == FilterType.flag).toList();
    final statusSuggestions =
        _filteredSuggestions.where((s) => s.type == FilterType.status).toList();
    final sourceSuggestions =
        _filteredSuggestions.where((s) => s.type == FilterType.source).toList();
    final prStatusSuggestions = _filteredSuggestions
        .where((s) => s.type == FilterType.prStatus)
        .toList();
    final ciStatusSuggestions = _filteredSuggestions
        .where((s) => s.type == FilterType.ciStatus)
        .toList();
    final otherSuggestions =
        _filteredSuggestions.where((s) => s.type == FilterType.text).toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 600, // Wider for multi-column layout
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status column
                      if (statusSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'Status',
                            statusSuggestions,
                            Colors.blue,
                          ),
                        ),
                      if (statusSuggestions.isNotEmpty &&
                          (prStatusSuggestions.isNotEmpty ||
                              flagSuggestions.isNotEmpty ||
                              sourceSuggestions.isNotEmpty))
                        const VerticalDivider(width: 1),

                      // PR Status column
                      if (prStatusSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'PR Status',
                            prStatusSuggestions,
                            Colors.purple,
                          ),
                        ),
                      if (prStatusSuggestions.isNotEmpty &&
                          (ciStatusSuggestions.isNotEmpty ||
                              flagSuggestions.isNotEmpty ||
                              sourceSuggestions.isNotEmpty))
                        const VerticalDivider(width: 1),

                      // CI Status column
                      if (ciStatusSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'CI Status',
                            ciStatusSuggestions,
                            Colors.blueGrey,
                          ),
                        ),
                      if (ciStatusSuggestions.isNotEmpty &&
                          (flagSuggestions.isNotEmpty ||
                              sourceSuggestions.isNotEmpty))
                        const VerticalDivider(width: 1),

                      // Flags column
                      if (flagSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'Flags',
                            flagSuggestions,
                            Colors.orange,
                          ),
                        ),
                      if (flagSuggestions.isNotEmpty &&
                          sourceSuggestions.isNotEmpty)
                        const VerticalDivider(width: 1),

                      // Sources column
                      if (sourceSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'Sources',
                            sourceSuggestions,
                            Colors.green,
                          ),
                        ),
                      if (sourceSuggestions.isNotEmpty &&
                          otherSuggestions.isNotEmpty)
                        const VerticalDivider(width: 1),

                      // Other/Text column
                      if (otherSuggestions.isNotEmpty)
                        Expanded(
                          child: _buildFilterColumn(
                            'Other',
                            otherSuggestions,
                            Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildFilterColumn(
    String title,
    List<FilterToken> suggestions,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ),
        ...suggestions.asMap().entries.map((entry) {
          final suggestion = entry.value;
          final globalIndex = _filteredSuggestions.indexOf(suggestion);
          final isHighlighted = globalIndex == _highlightedIndex;

          return InkWell(
            onTap: () => _selectSuggestion(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isHighlighted ? Colors.blue.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconForType(suggestion.type),
                    size: 14,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suggestion.label,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
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
      case FilterType.prStatus:
        newElement = PrStatusElement(token.label, token.value.toString());
        break;
      case FilterType.ciStatus:
        newElement = CiStatusElement(token.label, token.value.toString());
        break;
      case FilterType.branch:
        newElement = BranchElement(token.label, token.value.toString());
        break;
      case FilterType.text:
        // Text search is handled separately, not in tree
        return;
      case FilterType.time:
        newElement = TimeFilterElement(token.value);
        break;
    }

    // Handle exclude mode
    if (token.mode == FilterMode.exclude) {
      newElement = NotElement(newElement);
    }

    // Add to tree using smart builder
    final newTree = FilterElementBuilder.addFilter(
      widget.filterTree,
      newElement,
    );
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
      case FilterType.prStatus:
        return Icons.merge; // PR icon
      case FilterType.ciStatus:
        return Icons.check_circle_outline;
      case FilterType.branch:
        return Icons.account_tree;
      case FilterType.text:
        return Icons.text_fields;
      case FilterType.time:
        return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<FilterToken>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _selectSuggestion(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Card(
          elevation: isHovering ? 8 : 2,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isHovering ? Colors.blue.shade300 : Colors.transparent,
              width: 2,
            ),
          ),
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
                                widget.filterTree,
                                element,
                              );
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
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
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
                    IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final filterToken = await showDialog<FilterToken>(
                          context: context,
                          builder: (context) => const TimeFilterDialog(),
                        );
                        if (filterToken != null) {
                          _selectSuggestion(filterToken);
                        }
                      },
                      tooltip: 'Filter by Time',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Filters and Sorts inline
                if (widget.filterTree != null || true)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Tree (Expanded)
                        Expanded(
                          child: widget.filterTree != null
                              ? Theme(
                                  data: Theme.of(context).copyWith(
                                    dividerColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                  ),
                                  child: ExpansionTile(
                                    title: _isFilterExpanded
                                        ? const Text(
                                            "Active Filters",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey,
                                            ),
                                          )
                                        : TextField(
                                            controller: _expressionController,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.blueAccent,
                                              fontFamily: 'monospace',
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onSubmitted: (value) {
                                              final newTree =
                                                  FilterExpressionParser.parse(
                                                value,
                                              );
                                              widget.onFilterTreeChanged(
                                                newTree,
                                              );
                                            },
                                          ),
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: EdgeInsets.zero,
                                    showTrailingIcon: true,
                                    shape: const Border(),
                                    collapsedShape: const Border(),
                                    initiallyExpanded: _isFilterExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _isFilterExpanded = expanded;
                                      });
                                    },
                                    children: [
                                      Align(
                                        alignment: Alignment.topLeft,
                                        child: FilterElementWidget(
                                          element: widget.filterTree,
                                          onAddAlternative:
                                              (target, alternative) {
                                            final newTree = FilterElementBuilder
                                                .groupFilters(
                                              widget.filterTree,
                                              target,
                                              alternative,
                                              isAnd: false,
                                            );
                                            final simplified =
                                                FilterElementBuilder.simplify(
                                              newTree,
                                            );
                                            widget.onFilterTreeChanged(
                                              simplified,
                                            );
                                          },
                                          onDrop: (source, target, action,
                                              isCtrlPressed) {
                                            var newTree = widget.filterTree;

                                            // Clone source so we can add a new instance and remove the old one (if move)
                                            final sourceCopy =
                                                FilterElement.fromJson(
                                              source.toJson(),
                                            );
                                            final isCopy = isCtrlPressed;

                                            // 1. Perform the Add/Group operation with the Copy
                                            switch (action) {
                                              case FilterDropAction.groupOr:
                                                newTree = FilterElementBuilder
                                                    .groupFilters(
                                                  newTree,
                                                  target,
                                                  sourceCopy,
                                                  isAnd: false,
                                                );
                                                break;
                                              case FilterDropAction.groupAnd:
                                                newTree = FilterElementBuilder
                                                    .groupFilters(
                                                  newTree,
                                                  target,
                                                  sourceCopy,
                                                  isAnd: true,
                                                );
                                                break;
                                              case FilterDropAction.addToGroup:
                                                newTree = FilterElementBuilder
                                                    .addFilterToComposite(
                                                  newTree,
                                                  target,
                                                  sourceCopy,
                                                );
                                                break;
                                              case FilterDropAction
                                                    .groupAboveAnd:
                                                newTree = FilterElementBuilder
                                                    .groupFilters(
                                                  newTree,
                                                  target,
                                                  sourceCopy,
                                                  isAnd: true,
                                                );
                                                break;
                                              case FilterDropAction
                                                    .groupAboveOr:
                                                newTree = FilterElementBuilder
                                                    .groupFilters(
                                                  newTree,
                                                  target,
                                                  sourceCopy,
                                                  isAnd: false,
                                                );
                                                break;
                                            }

                                            // 2. Remove the original source if it is a move operation
                                            if (!isCopy && newTree != null) {
                                              newTree = FilterElementBuilder
                                                  .removeFilter(
                                                newTree,
                                                source,
                                              );
                                            }

                                            // 3. Simplify and update
                                            final simplified =
                                                FilterElementBuilder.simplify(
                                              newTree,
                                            );
                                            widget.onFilterTreeChanged(
                                              simplified,
                                            );
                                          },
                                          onRemove: (element) {
                                            final newTree = FilterElementBuilder
                                                .removeFilter(
                                              widget.filterTree,
                                              element,
                                            );
                                            final simplified =
                                                FilterElementBuilder.simplify(
                                              newTree,
                                            );
                                            widget.onFilterTreeChanged(
                                              simplified,
                                            );
                                          },
                                          onToggleNot: (element) {
                                            final newTree =
                                                FilterElementBuilder.toggleNot(
                                              widget.filterTree!,
                                              element,
                                            );
                                            widget.onFilterTreeChanged(newTree);
                                          },
                                          onTap: null,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        // Sort Pills (Fixed width, right aligned via structure)
                        SortPillsWidget(
                          activeSorts: widget.activeSorts,
                          onSortsChanged: widget.onSortsChanged,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
