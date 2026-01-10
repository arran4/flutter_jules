import 'package:flutter/material.dart';
import '../../models/source.dart';

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

      final isSourceA = labelA.startsWith('sources/') || a.name.startsWith('sources/');
      final isSourceB = labelB.startsWith('sources/') || b.name.startsWith('sources/');

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
                itemCount: _filteredSources.length,
                itemBuilder: (context, index) {
                  final source = _filteredSources[index];
                  final isSelected = _isSelected(source);
                  final isPrivate = source.githubRepo?.isPrivate ?? false;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(source),
                    title: Text(_getSourceDisplayLabel(source)),
                    secondary: isPrivate ? const Icon(Icons.lock, size: 16) : null,
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
