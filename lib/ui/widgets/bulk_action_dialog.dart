import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bulk_action.dart';
import '../../models/session.dart';
import '../../models/search_filter.dart';
import '../../models/filter_element.dart';
import '../../services/session_provider.dart';
import '../../services/message_queue_provider.dart';
import 'advanced_search_bar.dart';
import 'bulk_action_progress_dialog.dart';

class BulkActionDialog extends StatefulWidget {
  final FilterElement? currentFilterTree;
  final List<SortOption> currentSorts;
  final List<FilterToken> availableSuggestions;
  final BulkTargetType initialTarget;
  final List<Session> visibleSessions;
  final String mainSearchText;

  const BulkActionDialog({
    super.key,
    required this.currentFilterTree,
    required this.currentSorts,
    required this.availableSuggestions,
    required this.visibleSessions,
    required this.mainSearchText,
    this.initialTarget = BulkTargetType.visible,
  });

  @override
  State<BulkActionDialog> createState() => _BulkActionDialogState();
}

class _BulkActionDialogState extends State<BulkActionDialog> {
  late BulkTargetType _targetType;
  FilterElement? _filterTree;
  late List<SortOption> _sorts;
  final List<BulkActionStep> _actions = [];
  int _parallelQueries = 1;
  int _waitBetweenSeconds = 2;
  String _searchText = '';
  
  List<Session> _previewSessions = [];
  int _totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _targetType = widget.initialTarget;
    _filterTree = widget.currentFilterTree;
    _sorts = List.from(widget.currentSorts);
    _searchText = widget.mainSearchText;
    
    // Add a default action
    _actions.add(BulkActionStep(type: BulkActionType.refreshSession));

    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
  }

  void _updatePreview() {
    final sessionProvider = context.read<SessionProvider>();
    final queueProvider = context.read<MessageQueueProvider>();

    List<Session> allMatches = [];
    if (_targetType == BulkTargetType.visible) {
      allMatches = List<Session>.from(widget.visibleSessions);
    } else {
      // Sessions based on the CUSTOM filter tree and search text in this dialog
      allMatches = sessionProvider.items.where((item) {
        final session = item.data;
        final metadata = item.metadata;

        // Apply dialog-local search text
        if (_searchText.isNotEmpty) {
          final query = _searchText.toLowerCase();
          final titleMatches =
              (session.title?.toLowerCase().contains(query) ?? false) ||
              (session.name.toLowerCase().contains(query)) ||
              (session.id.toLowerCase().contains(query)) ||
              (session.state?.displayName.toLowerCase().contains(query) ??
                  false);
          if (!titleMatches) return false;
        }

        final initialState = metadata.isHidden
            ? FilterState.implicitOut
            : FilterState.implicitIn;

        if (_filterTree == null) {
          return initialState.isIn;
        }

        final treeResult = _filterTree!.evaluate(
          FilterContext(
            session: session,
            metadata: metadata,
            queueProvider: queueProvider,
          ),
        );

        final finalState = FilterState.combineAnd(initialState, treeResult);
        return finalState.isIn;
      }).map((item) => item.data).toList();
    }

    if (mounted) {
      setState(() {
        _totalMatches = allMatches.length;
        _previewSessions = allMatches.take(50).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Actions'),
      content: SizedBox(
        width: 900,
        height: 700,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Configuration
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. Target Sessions'),
                    SegmentedButton<BulkTargetType>(
                      segments: const [
                        ButtonSegment(value: BulkTargetType.visible, label: Text('Visible Items'), icon: Icon(Icons.visibility)),
                        ButtonSegment(value: BulkTargetType.filtered, label: Text('Filtered Items'), icon: Icon(Icons.filter_alt)),
                      ],
                      selected: {_targetType},
                      onSelectionChanged: (val) {
                         setState(() => _targetType = val.first);
                         _updatePreview();
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_targetType == BulkTargetType.filtered) ...[
                      const Text("Customize Filters:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      AdvancedSearchBar(
                        filterTree: _filterTree,
                        onFilterTreeChanged: (tree) {
                          setState(() => _filterTree = tree);
                          _updatePreview();
                        },
                        searchText: _searchText,
                        onSearchChanged: (text) {
                          setState(() => _searchText = text);
                          _updatePreview();
                        },
                        availableSuggestions: widget.availableSuggestions,
                        activeSorts: _sorts,
                        onSortsChanged: (s) {
                          setState(() => _sorts = s);
                          _updatePreview();
                        },
                        showBookmarksButton: false,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildSectionHeader('2. Actions to Perform'),
                    const Text("Actions run in order. If one fails, the rest for that session are skipped.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildActionList(),
                    TextButton.icon(
                      onPressed: _addNewAction,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Action"),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('3. Execution Settings'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Parallel Queries',
                            value: _parallelQueries,
                            onChanged: (v) => setState(() => _parallelQueries = v),
                            min: 1,
                            max: 10,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNumberInput(
                            label: 'Wait Between (sec)',
                            value: _waitBetweenSeconds,
                            onChanged: (v) => setState(() => _waitBetweenSeconds = v),
                            min: 0,
                            max: 60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 32),
            // Right: Preview
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Preview Matches'),
                  Text(
                    '$_totalMatches sessions total${_totalMatches > 50 ? ' (showing top 50)' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _previewSessions.isEmpty
                          ? const Center(child: Text("No matches found."))
                          : ListView.builder(
                              itemCount: _previewSessions.length,
                              itemBuilder: (context, index) => _buildLiteTile(_previewSessions[index]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _totalMatches > 0 && _actions.isNotEmpty ? _startJob : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run Bulk Actions'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildActionList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        itemCount: _actions.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _actions.removeAt(oldIndex);
            _actions.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final action = _actions[index];
          return ListTile(
            key: ValueKey(action.hashCode ^ index),
            leading: const Icon(Icons.drag_handle, size: 20),
            title: Row(
              children: [
                Expanded(
                  child: DropdownButton<BulkActionType>(
                    value: action.type,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: BulkActionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (newType) {
                      if (newType != null) {
                        setState(() {
                          _actions[index] = BulkActionStep(type: newType, message: action.message);
                        });
                      }
                    },
                  ),
                ),
                if (action.type.requiresMessage) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: action.type == BulkActionType.sleep ? 'Seconds' : 'Message...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 12),
                      controller: TextEditingController(text: action.message)..selection = TextSelection.collapsed(offset: (action.message ?? '').length),
                      onChanged: (val) {
                         _actions[index] = BulkActionStep(type: action.type, message: val);
                      },
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
              onPressed: () => setState(() => _actions.removeAt(index)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberInput({required String label, required int value, required Function(int) onChanged, required int min, required int max}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Row(
          children: [
            IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }

  Widget _buildLiteTile(Session session) {
    final isDraft = session.id.startsWith('DRAFT_CREATION_');
    return ListTile(
      dense: true,
      title: Text(
        "${session.title ?? session.name}${isDraft ? ' (Draft)' : ''}",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        "ID: ${session.id.length > 20 ? '${session.id.substring(0, 10)}...${session.id.substring(session.id.length - 10)}' : session.id} • ${session.state?.displayName ?? 'Unknown'}",
        style: const TextStyle(fontSize: 9),
      ),
    );
  }

  void _addNewAction() {
    setState(() {
      _actions.add(BulkActionStep(type: BulkActionType.refreshSession));
    });
  }

  void _startJob() {
    final config = BulkJobConfig(
      targetType: _targetType,
      filterTree: _filterTree,
      sorts: _sorts,
      actions: _actions,
      parallelQueries: _parallelQueries,
      waitBetweenSeconds: _waitBetweenSeconds,
    );
    
    final List<Session> targets;
    if (_targetType == BulkTargetType.visible) {
      targets = List<Session>.from(widget.visibleSessions);
    } else {
      final sessionProvider = context.read<SessionProvider>();
      final queueProvider = context.read<MessageQueueProvider>();

      targets = sessionProvider.items.where((item) {
        final session = item.data;
        final metadata = item.metadata;

        // Apply text search
        if (_searchText.isNotEmpty) {
          final query = _searchText.toLowerCase();
          final matches =
              (session.title?.toLowerCase().contains(query) ?? false) ||
              (session.name.toLowerCase().contains(query)) ||
              (session.id.toLowerCase().contains(query)) ||
              (session.state.toString().toLowerCase().contains(query));
          if (!matches) return false;
        }

        final initialState =
            metadata.isHidden ? FilterState.implicitOut : FilterState.implicitIn;

        if (_filterTree == null) {
          return initialState.isIn;
        }

        final treeResult = _filterTree!.evaluate(
          FilterContext(
            session: session,
            metadata: metadata,
            queueProvider: queueProvider,
          ),
        );

        final finalState = FilterState.combineAnd(initialState, treeResult);
        return finalState.isIn;
      }).map((item) => item.data).toList();
    }

    Navigator.pop(context); // Close config dialog
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BulkActionProgressDialog(
        config: config,
        targets: targets,
      ),
    );
  }
}
