import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_provider.dart';
import '../../models.dart';

class BulkSourceSelectorDialog extends StatefulWidget {
  final List<Source> availableSources;
  final List<Source> initialSelectedSources;

  const BulkSourceSelectorDialog({
    super.key,
    required this.availableSources,
    this.initialSelectedSources = const [],
  });

  @override
  State<BulkSourceSelectorDialog> createState() =>
      _BulkSourceSelectorDialogState();
}

class _BulkSourceSelectorDialogState extends State<BulkSourceSelectorDialog> {
  late List<Source> _selectedSources;
  late List<Source> _filteredSources;
  List<SourceGroup> _filteredGroups = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedSources = List.from(widget.initialSelectedSources);
    _filteredSources = List.from(widget.availableSources);
    _sortSources();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateGroups();
  }

  void _updateGroups() {
    final settings = Provider.of<SettingsProvider>(context);
    final query = _searchController.text.toLowerCase();
    _filteredGroups = settings.sourceGroups.where((g) {
      return query.isEmpty || g.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSources = widget.availableSources.where((s) {
        final label = _getSourceDisplayLabel(s).toLowerCase();
        return label.contains(query);
      }).toList();
      _sortSources();
      _updateGroups();
    });
  }

  void _sortSources() {
    _filteredSources.sort((a, b) {
      final labelA = _getSourceDisplayLabel(a);
      final labelB = _getSourceDisplayLabel(b);

      // Selected items first? Or just alpha?
      // Usually alpha is better for finding.
      // But maybe selected first is nice.
      // Let's stick to the logic in NewSessionDialog: sources/ last, then alpha.

      final isSourceA =
          labelA.startsWith('sources/') || a.name.startsWith('sources/');
      final isSourceB =
          labelB.startsWith('sources/') || b.name.startsWith('sources/');

      if (isSourceA != isSourceB) {
        return isSourceA ? 1 : -1;
      }
      return labelA.compareTo(labelB);
    });
  }

  bool _isSelected(Source s) {
    return _selectedSources.any((selected) => selected.name == s.name);
  }

  void _toggleSelection(Source s) {
    setState(() {
      if (_isSelected(s)) {
        _selectedSources.removeWhere((selected) => selected.name == s.name);
      } else {
        _selectedSources.add(s);
      }
    });
  }

  String _getSourceDisplayLabel(Source s) {
    if (s.githubRepo != null) {
      return '${s.githubRepo!.owner}/${s.githubRepo!.repo}';
    }
    return s.name;
  }

  bool? _isGroupSelected(SourceGroup g) {
    final groupSources = widget.availableSources
        .where((s) => g.sourceNames.contains(s.name))
        .toList();
    if (groupSources.isEmpty) return false;

    final selectedCount = groupSources.where((s) => _isSelected(s)).length;
    if (selectedCount == groupSources.length) return true;
    if (selectedCount > 0) return null; // tristate
    return false;
  }

  void _toggleGroup(SourceGroup g) {
    final groupSources = widget.availableSources
        .where((s) => g.sourceNames.contains(s.name))
        .toList();
    final allSelected = groupSources.every((s) => _isSelected(s));

    setState(() {
      if (allSelected) {
        // Deselect all
        for (final s in groupSources) {
          _selectedSources.removeWhere((selected) => selected.name == s.name);
        }
      } else {
        // Select all
        for (final s in groupSources) {
          if (!_isSelected(s)) {
            _selectedSources.add(s);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Repositories'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredGroups.length + _filteredSources.length,
                itemBuilder: (context, index) {
                  if (index < _filteredGroups.length) {
                    final group = _filteredGroups[index];
                    return _GroupCheckboxTile(
                      group: group,
                      isSelected: _isGroupSelected(group),
                      onToggle: _toggleGroup,
                    );
                  }

                  final source =
                      _filteredSources[index - _filteredGroups.length];
                  return _SourceCheckboxTile(
                    source: source,
                    isSelected: _isSelected(source),
                    displayLabel: _getSourceDisplayLabel(source),
                    onToggle: _toggleSelection,
                  );
                },
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
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _selectedSources);
          },
          child: Text('Select (${_selectedSources.length})'),
        ),
      ],
    );
  }
}

class _GroupCheckboxTile extends StatelessWidget {
  final SourceGroup group;
  final bool? isSelected;
  final ValueChanged<SourceGroup> onToggle;

  const _GroupCheckboxTile({
    required this.group,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: isSelected,
      tristate: true,
      onChanged: (_) => onToggle(group),
      title: Text(group.name),
      secondary: const Icon(Icons.group, size: 16),
      subtitle: Text('${group.sourceNames.length} repositories'),
    );
  }
}

class _SourceCheckboxTile extends StatelessWidget {
  final Source source;
  final bool isSelected;
  final String displayLabel;
  final ValueChanged<Source> onToggle;

  const _SourceCheckboxTile({
    required this.source,
    required this.isSelected,
    required this.displayLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivate = source.githubRepo?.isPrivate ?? false;

    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) => onToggle(source),
      title: Text(displayLabel),
      secondary: isPrivate ? const Icon(Icons.lock, size: 16) : null,
    );
  }
}
