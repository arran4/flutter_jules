import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/filter_element.dart';
import '../../models/filter_element_builder.dart';
import '../../models/search_filter.dart';
import 'filter_element_widget.dart';
import 'package:provider/provider.dart';
import '../../models/filter_bookmark.dart';
import '../../models/time_filter.dart';
import '../../services/filter_bookmark_provider.dart';
import '../screens/bookmark_manager_screen.dart';
import '../../models/preset_state_manager.dart';
import 'sort_pills_widget.dart';
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
  final TextEditingController _formulaController = TextEditingController();
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  final LayerLink _presetLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _presetOverlayEntry;
  List<FilterToken> _filteredSuggestions = [];
  int _highlightedIndex = 0;
  bool _activeFiltersExpanded = true;
  final GlobalKey _presetButtonKey = GlobalKey();
  final PresetStateManager _presetStateManager = PresetStateManager();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.searchText;
    _expressionController.text = widget.filterTree?.toExpression() ?? '';
    _updateFormulaText();
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
      _presetStateManager.onFilterChanged(widget.filterTree);
    }
    if (widget.filterTree != oldWidget.filterTree ||
        widget.activeSorts != oldWidget.activeSorts) {
      _updateFormulaText();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _removePresetOverlay();
    _textController.dispose();
    _expressionController.dispose();
    _formulaController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateFormulaText() {
    final filterExpression = widget.filterTree?.toExpression() ?? '';
    final sortExpression =
        widget.activeSorts.map((s) => s.toExpression()).join(', ');
    final fullExpression =
        '$filterExpression ${sortExpression.isNotEmpty ? 'SORT BY $sortExpression' : ''}'
            .trim();
    if (_formulaController.text != fullExpression) {
      _formulaController.text = fullExpression;
    }
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

  List<FilterToken> _getTimeSuggestions() {
    return [
      FilterToken(
        id: 'time_15m',
        type: FilterType.time,
        label: 'Last 15 minutes',
        value: TimeFilter(type: TimeFilterType.newerThan, range: '15 minutes'),
      ),
      FilterToken(
        id: 'time_1h',
        type: FilterType.time,
        label: 'Last 1 hour',
        value: TimeFilter(type: TimeFilterType.newerThan, range: '1 hour'),
      ),
      FilterToken(
        id: 'time_24h',
        type: FilterType.time,
        label: 'Last 24 hours',
        value: TimeFilter(type: TimeFilterType.newerThan, range: '24 hours'),
      ),
      FilterToken(
        id: 'time_7d',
        type: FilterType.time,
        label: 'Last 7 days',
        value: TimeFilter(type: TimeFilterType.newerThan, range: '7 days'),
      ),
      const FilterToken(
        id: 'time_updated_before',
        type: FilterType.time,
        label: 'Updated before...',
        value: null,
      ),
      const FilterToken(
        id: 'time_updated_after',
        type: FilterType.time,
        label: 'Updated after...',
        value: null,
      ),
      const FilterToken(
        id: 'time_created_before',
        type: FilterType.time,
        label: 'Created before...',
        value: null,
      ),
      const FilterToken(
        id: 'time_created_after',
        type: FilterType.time,
        label: 'Created after...',
        value: null,
      ),
      const FilterToken(
        id: 'time_updated_between',
        type: FilterType.time,
        label: 'Updated between...',
        value: null,
      ),
      const FilterToken(
        id: 'time_created_between',
        type: FilterType.time,
        label: 'Created between...',
        value: null,
      ),
      const FilterToken(
        id: 'time_updated_on',
        type: FilterType.time,
        label: 'Updated on...',
        value: null,
      ),
      const FilterToken(
        id: 'time_created_on',
        type: FilterType.time,
        label: 'Created on...',
        value: null,
      ),
      const FilterToken(
        id: 'time_custom',
        type: FilterType.time,
        label: 'Custom...',
        value: null,
      ),
    ];
  }

  void _tryCommitFilter(String text, int atIndex) {
    final query = text.substring(atIndex + 1).toLowerCase();
    final allSuggestions = _buildSuggestionsList();
    _filteredSuggestions = _filterSuggestions(allSuggestions, query);

    _highlightedIndex = 0;

    if (_filteredSuggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  List<FilterToken> _buildSuggestionsList() {
    final timeSuggestions = _getTimeSuggestions();
    return [...widget.availableSuggestions, ...timeSuggestions];
  }

  List<FilterToken> _filterSuggestions(
    List<FilterToken> suggestions,
    String query,
  ) {
    if (query.isEmpty) {
      return suggestions;
    }

    return suggestions.where((s) {
      return s.label.toLowerCase().contains(query) ||
          s.id.toLowerCase().contains(query);
    }).toList();
  }

  KeyEventResult _handleFocusKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_overlayEntry != null && _filteredSuggestions.isNotEmpty) {
      if (_handleArrowDown(event)) return KeyEventResult.handled;
      if (_handleArrowUp(event)) return KeyEventResult.handled;
      if (_handleSuggestionCommit(event)) return KeyEventResult.handled;
      if (_handleEscape(event)) return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _handleArrowDown(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return false;
    }

    setState(() {
      _highlightedIndex = (_highlightedIndex + 1) % _filteredSuggestions.length;
    });
    _showOverlay();
    return true;
  }

  bool _handleArrowUp(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return false;
    }

    setState(() {
      _highlightedIndex = (_highlightedIndex - 1) < 0
          ? _filteredSuggestions.length - 1
          : _highlightedIndex - 1;
    });
    _showOverlay();
    return true;
  }

  bool _handleSuggestionCommit(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.tab) {
      return false;
    }

    if (_highlightedIndex < _filteredSuggestions.length) {
      _selectSuggestion(_filteredSuggestions[_highlightedIndex]);
      return true;
    }

    return false;
  }

  bool _handleEscape(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }

    _removeOverlay();
    return true;
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = _buildSuggestionsOverlayEntry();

    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _buildSuggestionsOverlayEntry() {
    final groups = _groupSuggestionsByType(_filteredSuggestions);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: 800, // Wider for multi-column layout
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: _buildSuggestionsOverlayContent(groups),
        ),
      ),
    );
  }

  Widget _buildSuggestionsOverlayContent(_SuggestionGroups groups) {
    return Material(
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
                if (groups.statusSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'Status',
                      groups.statusSuggestions,
                      Colors.blue,
                    ),
                  ),
                if (groups.statusSuggestions.isNotEmpty &&
                    (groups.prStatusSuggestions.isNotEmpty ||
                        groups.flagSuggestions.isNotEmpty ||
                        groups.sourceSuggestions.isNotEmpty ||
                        groups.timeSuggestions.isNotEmpty))
                  const VerticalDivider(width: 1),

                // PR Status column
                if (groups.prStatusSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'PR Status',
                      groups.prStatusSuggestions,
                      Colors.purple,
                    ),
                  ),
                if (groups.prStatusSuggestions.isNotEmpty &&
                    (groups.ciStatusSuggestions.isNotEmpty ||
                        groups.flagSuggestions.isNotEmpty ||
                        groups.sourceSuggestions.isNotEmpty ||
                        groups.timeSuggestions.isNotEmpty))
                  const VerticalDivider(width: 1),

                // CI Status column
                if (groups.ciStatusSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'CI Status',
                      groups.ciStatusSuggestions,
                      Colors.blueGrey,
                    ),
                  ),
                if (groups.ciStatusSuggestions.isNotEmpty &&
                    (groups.flagSuggestions.isNotEmpty ||
                        groups.sourceSuggestions.isNotEmpty ||
                        groups.timeSuggestions.isNotEmpty))
                  const VerticalDivider(width: 1),

                // Flags column
                if (groups.flagSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'Flags',
                      groups.flagSuggestions,
                      Colors.orange,
                    ),
                  ),
                if (groups.flagSuggestions.isNotEmpty &&
                    (groups.sourceSuggestions.isNotEmpty ||
                        groups.timeSuggestions.isNotEmpty))
                  const VerticalDivider(width: 1),

                // Sources column
                if (groups.sourceSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'Sources',
                      groups.sourceSuggestions,
                      Colors.green,
                    ),
                  ),
                if (groups.sourceSuggestions.isNotEmpty &&
                    (groups.timeSuggestions.isNotEmpty ||
                        groups.otherSuggestions.isNotEmpty))
                  const VerticalDivider(width: 1),

                // Time column
                if (groups.timeSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'Time',
                      groups.timeSuggestions,
                      Colors.teal,
                    ),
                  ),
                if (groups.timeSuggestions.isNotEmpty &&
                    groups.otherSuggestions.isNotEmpty)
                  const VerticalDivider(width: 1),

                // Other/Text column
                if (groups.otherSuggestions.isNotEmpty)
                  Expanded(
                    child: _buildFilterColumn(
                      'Other',
                      groups.otherSuggestions,
                      Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _SuggestionGroups _groupSuggestionsByType(List<FilterToken> suggestions) {
    return _SuggestionGroups(
      flagSuggestions:
          suggestions.where((s) => s.type == FilterType.flag).toList(),
      statusSuggestions:
          suggestions.where((s) => s.type == FilterType.status).toList(),
      sourceSuggestions:
          suggestions.where((s) => s.type == FilterType.source).toList(),
      prStatusSuggestions:
          suggestions.where((s) => s.type == FilterType.prStatus).toList(),
      ciStatusSuggestions:
          suggestions.where((s) => s.type == FilterType.ciStatus).toList(),
      timeSuggestions:
          suggestions.where((s) => s.type == FilterType.time).toList(),
      otherSuggestions:
          suggestions.where((s) => s.type == FilterType.text).toList(),
    );
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
              child: _buildSuggestionRow(suggestion, accentColor),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSuggestionRow(FilterToken suggestion, Color accentColor) {
    return Row(
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
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectSuggestion(FilterToken token) {
    final builders = <FilterType, FilterElement? Function(FilterToken)>{
      FilterType.flag: (token) {
        if (token.value.toString() == 'has_pr' || token.id == 'flag:has_pr') {
          return HasPrElement();
        }
        return LabelElement(token.label, token.value.toString());
      },
      FilterType.status: (token) =>
          StatusElement(token.label, token.value.toString()),
      FilterType.source: (token) =>
          SourceElement(token.label, token.value.toString()),
      FilterType.prStatus: (token) =>
          PrStatusElement(token.label, token.value.toString()),
      FilterType.ciStatus: (token) =>
          CiStatusElement(token.label, token.value.toString()),
      FilterType.branch: (token) =>
          BranchElement(token.label, token.value.toString()),
      FilterType.tag: (token) =>
          TagElement(token.label, token.value.toString()),
      FilterType.text: (_) => null,
      FilterType.time: _buildTimeElement,
    };

    final builder = builders[token.type];
    if (builder == null) {
      return;
    }

    var newElement = builder(token);

    // Handle exclude mode
    if (newElement == null) return;

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

  FilterElement? _buildTimeElement(FilterToken token) {
    if (token.id == 'time_custom' || token.id.startsWith('time_')) {
      final presetConfigs = <String, (TimeFilterType, TimeFilterField)>{
        'time_updated_before': (
          TimeFilterType.olderThan,
          TimeFilterField.updated
        ),
        'time_updated_after': (
          TimeFilterType.newerThan,
          TimeFilterField.updated
        ),
        'time_created_before': (
          TimeFilterType.olderThan,
          TimeFilterField.created
        ),
        'time_created_after': (
          TimeFilterType.newerThan,
          TimeFilterField.created
        ),
        'time_updated_between': (
          TimeFilterType.between,
          TimeFilterField.updated
        ),
        'time_created_between': (
          TimeFilterType.between,
          TimeFilterField.created
        ),
        'time_updated_on': (TimeFilterType.between, TimeFilterField.updated),
        'time_created_on': (TimeFilterType.between, TimeFilterField.created),
      };

      final presetConfig = presetConfigs[token.id];
      final initialType = presetConfig?.$1;
      final initialField = presetConfig?.$2;

      if (initialType != null || token.id == 'time_custom') {
        _removeOverlay();
        showDialog<FilterToken>(
          context: context,
          builder: (context) => TimeFilterDialog(
            initialType: initialType,
            initialField: initialField,
          ),
        ).then((filterToken) {
          if (filterToken != null) {
            _selectSuggestion(filterToken);
          } else {
            _focusNode.requestFocus();
          }
        });
        return null;
      }
    }

    if (token.value != null) {
      return TimeFilterElement(token.value);
    }

    return null;
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
      case FilterType.tag:
        return Icons.tag;
    }
  }

  Future<void> _saveCurrentFilters(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );

    if (_presetStateManager.shouldPreFill(
      widget.filterTree,
      widget.activeSorts,
      bookmarkProvider,
    )) {
      nameController.text = _presetStateManager.lastLoadedBookmark!.name;
      descController.text =
          _presetStateManager.lastLoadedBookmark!.description ?? '';
    }

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
      expression: widget.filterTree?.toExpression() ?? '',
      sorts: widget.activeSorts,
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
                _buildSearchInputRow(),

                const SizedBox(height: 12),

                const SizedBox(height: 4),

                // Active Filters section
                if (widget.filterTree != null || widget.activeSorts.isNotEmpty)
                  _buildActiveFiltersSection(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchInputRow() {
    return Row(
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
        CompositedTransformTarget(
          link: _presetLayerLink,
          child: IconButton(
            key: _presetButtonKey,
            icon: const Icon(Icons.bookmarks),
            tooltip: 'Filter Presets',
            onPressed: _togglePresetMenu,
          ),
        ),
      ],
    );
  }

  void _togglePresetMenu() {
    if (_presetOverlayEntry != null) {
      _removePresetOverlay();
    } else {
      _showPresetOverlay();
    }
  }

  void _removePresetOverlay() {
    _presetOverlayEntry?.remove();
    _presetOverlayEntry = null;
  }

  void _showPresetOverlay() {
    _removeOverlay(); // Close search autocomplete if open

    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );

    final RenderBox? buttonBox =
        _presetButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonPos = buttonBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final buttonSize = buttonBox?.size ?? Size.zero;

    final size = MediaQuery.of(context).size;
    final maxH = size.height * 0.8;

    // Decide if we align left or right based on available space
    final isRightSide = buttonPos.dx > size.width / 2;

    Alignment targetAnchor;
    Alignment followerAnchor;
    double calcMaxWidth;

    if (isRightSide) {
      targetAnchor = Alignment.bottomRight;
      followerAnchor = Alignment.topRight;
      // Available space to the left of the button's right edge
      final availableLeft = buttonPos.dx + buttonSize.width - 16;
      calcMaxWidth = availableLeft;
    } else {
      targetAnchor = Alignment.bottomLeft;
      followerAnchor = Alignment.topLeft;
      // Available space to the right of the button's left edge
      final availableRight = size.width - buttonPos.dx - 16;
      calcMaxWidth = availableRight;
    }

    // Apply 80% constraint
    final maxW = size.width * 0.8;
    if (calcMaxWidth > maxW) calcMaxWidth = maxW;

    // Ensure minWidth isn't larger than maxWidth
    final minW = 350.0 > calcMaxWidth ? calcMaxWidth : 350.0;

    _presetOverlayEntry = _buildPresetOverlayEntry(
      bookmarkProvider: bookmarkProvider,
      targetAnchor: targetAnchor,
      followerAnchor: followerAnchor,
      minW: minW,
      maxW: calcMaxWidth,
      maxH: maxH,
    );

    Overlay.of(context).insert(_presetOverlayEntry!);
  }

  OverlayEntry _buildPresetOverlayEntry({
    required FilterBookmarkProvider bookmarkProvider,
    required Alignment targetAnchor,
    required Alignment followerAnchor,
    required double minW,
    required double maxW,
    required double maxH,
  }) {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible dismiss layer
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removePresetOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            child: CompositedTransformFollower(
              link: _presetLayerLink,
              showWhenUnlinked: false,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: const Offset(0, 5), // Slight vertical gap
              child: _buildPresetOverlayContent(
                bookmarkProvider: bookmarkProvider,
                minW: minW,
                maxW: maxW,
                maxH: maxH,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetOverlayContent({
    required FilterBookmarkProvider bookmarkProvider,
    required double minW,
    required double maxW,
    required double maxH,
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minW,
          maxWidth: maxW,
          maxHeight: maxH,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.bookmarks, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter Presets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _removePresetOverlay,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // My Presets
                    _buildPresetSection(
                      context,
                      'My Presets',
                      bookmarkProvider.bookmarks
                          .where(
                            (b) =>
                                !bookmarkProvider.isSystemBookmark(b.name),
                          )
                          .toList(),
                      isSystem: false,
                    ),

                    // System Presets
                    _buildPresetSection(
                      context,
                      'System Presets',
                      bookmarkProvider.bookmarks
                          .where(
                            (b) => bookmarkProvider.isSystemBookmark(b.name),
                          )
                          .toList(),
                      isSystem: true,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _removePresetOverlay();
                      _saveCurrentFilters(context);
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save Current'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _removePresetOverlay();
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () {
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => BookmarkManagerScreen(
                                  availableSuggestions:
                                      widget.availableSuggestions,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Manage'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSection(
    BuildContext context,
    String title,
    List<FilterBookmark> bookmarks, {
    required bool isSystem,
  }) {
    if (bookmarks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...bookmarks.map((bookmark) {
          final sortsText = bookmark.sorts.map((s) => s.label).join(', ');

          return InkWell(
            onTap: () {
              widget.onFilterTreeChanged(bookmark.tree);
              widget.onSortsChanged(bookmark.sorts);
              _presetStateManager.setLastLoadedBookmark(bookmark);
              _removePresetOverlay();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Applied preset: ${bookmark.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.bookmark,
                      size: 18,
                      color: isSystem
                          ? Colors.blue.shade400
                          : Colors.orange.shade400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BookmarkDetails(
                      bookmark: bookmark,
                      sortsText: sortsText,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveFiltersSection() {
    if (_activeFiltersExpanded) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.unfold_less, size: 16),
                label: const Text('Collapse'),
                onPressed: () => setState(() => _activeFiltersExpanded = false),
              ),
            ],
          ),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (widget.filterTree != null)
                    FilterElementWidget(
                      element: widget.filterTree,
                      onAddAlternative: (target, alternative) {
                        final newTree = FilterElementBuilder.groupFilters(
                          widget.filterTree,
                          target,
                          alternative,
                          isAnd: false,
                        );
                        final simplified = FilterElementBuilder.simplify(
                          newTree,
                        );
                        widget.onFilterTreeChanged(simplified);
                      },
                      onDrop: (source, target, action, isCtrlPressed) {
                        var newTree = widget.filterTree;
                        final sourceCopy = FilterElement.fromJson(
                          source.toJson(),
                        );
                        final isCopy = isCtrlPressed;

                        switch (action) {
                          case FilterDropAction.groupOr:
                            newTree = FilterElementBuilder.groupFilters(
                              newTree,
                              target,
                              sourceCopy,
                              isAnd: false,
                            );
                            break;
                          case FilterDropAction.groupAnd:
                            newTree = FilterElementBuilder.groupFilters(
                              newTree,
                              target,
                              sourceCopy,
                              isAnd: true,
                            );
                            break;
                          case FilterDropAction.addToGroup:
                            newTree = FilterElementBuilder.addFilterToComposite(
                              newTree,
                              target,
                              sourceCopy,
                            );
                            break;
                          case FilterDropAction.groupAboveAnd:
                            newTree = FilterElementBuilder.groupFilters(
                              newTree,
                              target,
                              sourceCopy,
                              isAnd: true,
                            );
                            break;
                          case FilterDropAction.groupAboveOr:
                            newTree = FilterElementBuilder.groupFilters(
                              newTree,
                              target,
                              sourceCopy,
                              isAnd: false,
                            );
                            break;
                        }

                        if (!isCopy && newTree != null) {
                          newTree = FilterElementBuilder.removeFilter(
                            newTree,
                            source,
                          );
                        }

                        final simplified = FilterElementBuilder.simplify(
                          newTree,
                        );
                        widget.onFilterTreeChanged(simplified);
                      },
                      onRemove: (element) {
                        final newTree = FilterElementBuilder.removeFilter(
                          widget.filterTree,
                          element,
                        );
                        final simplified = FilterElementBuilder.simplify(
                          newTree,
                        );
                        widget.onFilterTreeChanged(simplified);
                      },
                      onToggleNot: (element) {
                        final newTree = FilterElementBuilder.toggleNot(
                          widget.filterTree!,
                          element,
                        );
                        widget.onFilterTreeChanged(newTree);
                      },
                      onToggleEnabled: (element) {
                        final newTree = FilterElementBuilder.toggleEnabled(
                          widget.filterTree!,
                          element,
                        );
                        widget.onFilterTreeChanged(newTree);
                      },
                      onTap: null,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'No filters',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SortPillsWidget(
                    activeSorts: widget.activeSorts,
                    onSortsChanged: widget.onSortsChanged,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Collapsed view
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _formulaController,
                readOnly: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.black87,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.unfold_more, size: 16),
              onPressed: () => setState(() => _activeFiltersExpanded = true),
              tooltip: 'Expand filters',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
      );
    }
  }
}

class _SuggestionGroups {
  const _SuggestionGroups({
    required this.flagSuggestions,
    required this.statusSuggestions,
    required this.sourceSuggestions,
    required this.prStatusSuggestions,
    required this.ciStatusSuggestions,
    required this.timeSuggestions,
    required this.otherSuggestions,
  });

  final List<FilterToken> flagSuggestions;
  final List<FilterToken> statusSuggestions;
  final List<FilterToken> sourceSuggestions;
  final List<FilterToken> prStatusSuggestions;
  final List<FilterToken> ciStatusSuggestions;
  final List<FilterToken> timeSuggestions;
  final List<FilterToken> otherSuggestions;
}

class _BookmarkDetails extends StatelessWidget {
  const _BookmarkDetails({
    required this.bookmark,
    required this.sortsText,
  });

  final FilterBookmark bookmark;
  final String sortsText;

  @override
  Widget build(BuildContext context) {
    final description = bookmark.description;
    final hasDescription = description != null && description.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bookmark.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (hasDescription) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 12,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bookmark.expression.isEmpty
                          ? 'No filters'
                          : bookmark.expression,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (sortsText.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.sort,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sortsText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class PopupMenuHeader extends PopupMenuItem<FilterBookmark> {
  const PopupMenuHeader({super.key, required super.child})
      : super(enabled: false, height: 32);

  @override
  Widget? get child => MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
          child: super.child!,
        ),
      );
}
