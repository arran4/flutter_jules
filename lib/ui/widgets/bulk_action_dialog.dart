import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bulk_action.dart';
import '../../models/session.dart';
import '../../models/search_filter.dart';
import '../../models/filter_element.dart';
import '../../services/session_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/message_queue_provider.dart';
import 'advanced_search_bar.dart';
import 'bulk_action_progress_dialog.dart';
import 'delay_input_widget.dart';
import 'save_bulk_action_preset_dialog.dart';
import '../../models/bulk_action_preset.dart';
import '../../services/bulk_action_preset_provider.dart';
import '../../utils/action_script_builder.dart';
import '../../utils/action_script_parser.dart';
import '../../models/filter_expression_parser.dart';
import 'bulk_action_preset_dialog.dart';
import '../../models/bulk_action_preset_state_manager.dart';

class BulkActionDialog extends StatefulWidget {
  final FilterElement? currentFilterTree;
  final List<SortOption> currentSorts;
  final List<FilterToken> availableSuggestions;
  final String mainSearchText;
  final BulkActionPreset? initialPreset;

  const BulkActionDialog({
    super.key,
    required this.currentFilterTree,
    required this.currentSorts,
    required this.availableSuggestions,
    required this.mainSearchText,
    this.initialPreset,
  });

  @override
  State<BulkActionDialog> createState() => _BulkActionDialogState();
}

class _BulkActionDialogState extends State<BulkActionDialog> {
  FilterElement? _filterTree;
  late List<SortOption> _sorts;
  List<BulkActionStep> _actions = [];
  int _parallelQueries = 1;
  Duration _waitBetween = const Duration(seconds: 2);
  DelayUnit _waitBetweenUnit = DelayUnit.s;
  String _searchText = '';

  // Execution control
  int? _limit;
  int _offset = 0;
  bool _randomize = false;
  bool _stopOnError = false;

  List<Session> _previewSessions = [];
  int _totalMatches = 0;
  int _effectiveCount = 0; // After limit/offset

  final BulkActionPresetStateManager _stateManager =
      BulkActionPresetStateManager();

  @override
  void initState() {
    super.initState();
    _filterTree = widget.currentFilterTree;
    _sorts = List.from(widget.currentSorts);
    _searchText = widget.mainSearchText;

    if (widget.initialPreset != null) {
      _loadPresetInternal(widget.initialPreset!);
    } else {
      // Load last used settings
      final settings = context.read<SettingsProvider>();
      _actions = List<BulkActionStep>.from(settings.lastBulkActions);
      _parallelQueries = settings.lastBulkParallelQueries;
      _waitBetween =
          Duration(milliseconds: settings.lastBulkWaitBetweenMilliseconds);
      _waitBetweenUnit = settings.lastBulkWaitBetweenUnit;
      _limit = settings.lastBulkLimit;
      _offset = settings.lastBulkOffset;
      _randomize = settings.lastBulkRandomize;
      _stopOnError = settings.lastBulkStopOnError;
    }

    if (_actions.isEmpty) {
      _actions.add(const BulkActionStep(type: BulkActionType.refreshSession));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
  }

  void _loadPresetInternal(BulkActionPreset preset) {
    _stateManager.setLastLoadedPreset(preset);

    _filterTree = FilterExpressionParser.parse(preset.filterExpression);
    final config = ActionScriptParser.parse(preset.actionScript, _filterTree);

    _actions = config.actions;
    _parallelQueries = config.parallelQueries;
    _waitBetween = config.waitBetween;
    // We assume unit is seconds unless we parse it properly, but Duration is absolute.
    if (_waitBetween.inMilliseconds % 1000 == 0) {
      _waitBetweenUnit = DelayUnit.s;
    } else {
      _waitBetweenUnit = DelayUnit.ms;
    }

    _limit = config.limit;
    _offset = config.offset;
    _randomize = config.randomize;
    _stopOnError = config.stopOnError;
  }

  void _openLoadPresetDialog() async {
    final preset = await showDialog<BulkActionPreset>(
      context: context,
      builder: (context) => const BulkActionPresetDialog(isPicker: true),
    );

    if (preset != null && mounted) {
      setState(() {
        _loadPresetInternal(preset);
      });
      _updatePreview();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded preset: ${preset.name}')),
      );
    }
  }

  void _updatePreview() {
    final sessionProvider = context.read<SessionProvider>();
    final queueProvider = context.read<MessageQueueProvider>();

    final allMatches = sessionProvider.items
        .where((item) {
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
        })
        .map((item) => item.data)
        .toList();

    if (mounted) {
      setState(() {
        _totalMatches = allMatches.length;

        // Apply offset and limit for preview
        var effectiveMatches = allMatches;
        if (_offset > 0 && _offset < effectiveMatches.length) {
          effectiveMatches = effectiveMatches.sublist(_offset);
        } else if (_offset >= effectiveMatches.length) {
          effectiveMatches = [];
        }

        if (_limit != null && _limit! > 0) {
          effectiveMatches = effectiveMatches.take(_limit!).toList();
        }

        _effectiveCount = effectiveMatches.length;
        _previewSessions = effectiveMatches.take(50).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.8).clamp(800.0, 1800.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(600.0, 1200.0);

    return AlertDialog(
      title: const Text('Bulk Actions'),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
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
                    Text(
                      'Configure filters to target specific sessions. By default, your current filters and search are pre-loaded.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AdvancedSearchBar(
                      filterTree: _filterTree,
                      onFilterTreeChanged: (tree) {
                        setState(() => _filterTree = tree);
                        _stateManager.onStateChanged(tree);
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
                    _buildSectionHeader('2. Actions to Perform'),
                    const Text(
                      "Actions run in order. If one fails, the rest for that session are skipped.",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
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
                            onChanged: (v) =>
                                setState(() => _parallelQueries = v),
                            min: 1,
                            max: 10,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DelayInputWidget(
                            label: 'Wait Between',
                            initialDelay: _waitBetween,
                            initialUnit: _waitBetweenUnit,
                            onDelayChanged: (duration, unit) => setState(() {
                              _waitBetween = duration;
                              _waitBetweenUnit = unit;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('4. Execution Control'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Limit',
                                  hintText: 'Max sessions (blank = all)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                controller: TextEditingController(
                                  text: _limit != null ? _limit.toString() : '',
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _limit =
                                        val.isEmpty ? null : int.tryParse(val);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Offset',
                                  hintText: 'Skip first N',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                controller: TextEditingController(
                                  text: _offset > 0 ? _offset.toString() : '',
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _offset = val.isEmpty
                                        ? 0
                                        : (int.tryParse(val) ?? 0);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _randomize,
                          onChanged: (val) =>
                              setState(() => _randomize = val ?? false),
                          title: const Text(
                            'Randomize order',
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Process sessions in random order (useful for sampling)',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _stopOnError,
                          onChanged: (val) =>
                              setState(() => _stopOnError = val ?? false),
                          title: const Text(
                            'Stop on first error',
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Cancel entire job if any session fails',
                            style: TextStyle(fontSize: 10),
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      children: [
                        TextSpan(text: '$_totalMatches total'),
                        if (_effectiveCount != _totalMatches) ...[
                          const TextSpan(
                            text: ' → ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: '$_effectiveCount will run',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        if (_effectiveCount > 50)
                          const TextSpan(text: ' (showing top 50)'),
                      ],
                    ),
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
                              itemBuilder: (context, index) =>
                                  _buildLiteTile(_previewSessions[index]),
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
          onPressed: _openLoadPresetDialog,
          child: const Text('Load Preset...'),
        ),
        TextButton(
          onPressed: _saveAsPreset,
          child: const Text('Save as Preset...'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _totalMatches > 0 && _actions.isNotEmpty ? _startJob : null,
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
                        child: Text(
                          type.displayName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (newType) {
                      if (newType != null) {
                        setState(() {
                          _actions[index] = BulkActionStep(
                            type: newType,
                            message: action.message,
                          );
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
                        hintText: action.type == BulkActionType.sleep
                            ? 'Seconds'
                            : 'Message...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 12),
                      controller: TextEditingController(text: action.message)
                        ..selection = TextSelection.collapsed(
                          offset: (action.message ?? '').length,
                        ),
                      onChanged: (val) {
                        _actions[index] = BulkActionStep(
                          type: action.type,
                          message: val,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => setState(() => _actions.removeAt(index)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required Function(int) onChanged,
    required int min,
    required int max,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
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
      _actions.add(const BulkActionStep(type: BulkActionType.refreshSession));
    });
  }

  void _saveAsPreset() async {
    final provider = context.read<BulkActionPresetProvider>();
    String? initialName;
    String? initialDescription;

    if (_stateManager.shouldPreFill(provider.isSystemPreset(
        _stateManager.lastLoadedPreset?.name ?? ''))) {
      initialName = _stateManager.lastLoadedPreset!.name;
      initialDescription = _stateManager.lastLoadedPreset!.description;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => SaveBulkActionPresetDialog(
        initialName: initialName,
        initialDescription: initialDescription,
      ),
    );

    if (result != null && mounted) {
      final name = result['name']!;
      final description = result['description']!;

      final filterExpression = _filterTree?.toExpression() ?? '';
      final actionScript = buildActionScript(
        actions: _actions,
        parallelQueries: _parallelQueries,
        waitBetween: _waitBetween,
        limit: _limit,
        offset: _offset,
        randomize: _randomize,
        stopOnError: _stopOnError,
      );

      final newPreset = BulkActionPreset(
        name: name,
        description: description,
        filterExpression: filterExpression,
        actionScript: actionScript,
      );

      final existingPreset = provider.getPresetByName(name);

      if (existingPreset != null) {
        final contentDiffers =
            existingPreset.filterExpression != newPreset.filterExpression ||
                existingPreset.actionScript != newPreset.actionScript ||
                existingPreset.description != newPreset.description;

        if (contentDiffers) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Overwrite Preset?'),
              content: Text(
                'A preset with the name "$name" already exists with different content.\nDo you want to overwrite it?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Overwrite'),
                ),
              ],
            ),
          );

          if (confirm != true) return;
        }
      }

      await provider.addPreset(newPreset);
      _stateManager.setLastLoadedPreset(newPreset);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preset "$name" saved.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startJob() {
    // Save configuration
    context.read<SettingsProvider>().saveBulkActionConfig(
          actions: _actions,
          parallelQueries: _parallelQueries,
          waitBetweenMilliseconds: _waitBetween.inMilliseconds,
          waitBetweenUnit: _waitBetweenUnit,
          limit: _limit,
          offset: _offset,
          randomize: _randomize,
          stopOnError: _stopOnError,
        );

    final config = BulkJobConfig(
      targetType: BulkTargetType.filtered,
      filterTree: _filterTree,
      sorts: _sorts,
      actions: _actions,
      parallelQueries: _parallelQueries,
      waitBetween: _waitBetween,
      limit: _limit,
      offset: _offset,
      randomize: _randomize,
      stopOnError: _stopOnError,
    );

    final sessionProvider = context.read<SessionProvider>();
    final queueProvider = context.read<MessageQueueProvider>();

    var targets = sessionProvider.items
        .where((item) {
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
        })
        .map((item) => item.data)
        .toList();

    // Apply offset
    if (_offset > 0 && _offset < targets.length) {
      targets = targets.sublist(_offset);
    } else if (_offset >= targets.length) {
      targets = [];
    }

    // Apply limit
    if (_limit != null && _limit! > 0 && targets.length > _limit!) {
      targets = targets.take(_limit!).toList();
    }

    // Apply randomization
    if (_randomize && targets.isNotEmpty) {
      targets.shuffle();
    }

    Navigator.pop(context); // Close config dialog

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          BulkActionProgressDialog(config: config, targets: targets),
    );
  }
}
