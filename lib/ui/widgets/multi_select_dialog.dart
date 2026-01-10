import 'package:flutter/material.dart';
import '../../models.dart';
import '../../utils/search_helper.dart';

class MultiSelectDialog extends StatefulWidget {
  final List<Source> sources;

  const MultiSelectDialog({super.key, required this.sources});

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<Source> _filteredSources;
  final Set<String> _selectedSourceNames = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredSources = widget.sources;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredSources = filterAndSort<Source>(
        items: widget.sources,
        query: _searchController.text,
        accessors: [
          (item) => item.githubRepo?.repo ?? '',
          (item) => item.name,
          (item) => item.githubRepo?.owner ?? '',
        ],
      );
    });
  }

  void _selectAll() {
    setState(() {
      _selectedSourceNames.addAll(_filteredSources.map((s) => s.name));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedSourceNames.clear();
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
      title: const Text('Select Repositories for Bulk Creation'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Repositories',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text('Select All Visible'),
                ),
                TextButton(
                  onPressed: _deselectAll,
                  child: const Text('Deselect All'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSources.length,
                itemBuilder: (context, index) {
                  final source = _filteredSources[index];
                  final isSelected = _selectedSourceNames.contains(source.name);
                  return CheckboxListTile(
                    title: Text(_getSourceDisplayLabel(source)),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedSourceNames.add(source.name);
                        } else {
                          _selectedSourceNames.remove(source.name);
                        }
                      });
                    },
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
            final selectedSources = widget.sources
                .where((s) => _selectedSourceNames.contains(s.name))
                .toList();
            Navigator.pop(context, selectedSources);
          },
          child: Text('Create Sessions (${_selectedSourceNames.length})'),
        ),
      ],
    );
  }
}
