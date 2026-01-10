import 'dart:convert';

import 'package:flutter/material.dart';
import '../../models/filter_element.dart';
import '../../models/filter_element_builder.dart';
import '../widgets/filter_element_widget.dart';

/// Demo screen to showcase filter element rendering
class FilterElementDemo extends StatefulWidget {
  const FilterElementDemo({super.key});

  @override
  State<FilterElementDemo> createState() => _FilterElementDemoState();
}

class _FilterElementDemoState extends State<FilterElementDemo> {
  FilterElement? _currentFilter;

  @override
  void initState() {
    super.initState();
    _buildDemoFilter();
  }

  void _buildDemoFilter() {
    // Build a complex filter to demonstrate nesting:
    // AND(
    //   OR(Label(Unread), Label(New)),
    //   Status(Completed),
    //   NOT(HasPR())
    // )

    FilterElement? filter;

    // Add first label
    filter = FilterElementBuilder.addFilter(
        filter, LabelElement('Unread', 'unread'));

    // Add second label (will create OR)
    filter = FilterElementBuilder.addFilter(filter, LabelElement('New', 'new'));

    // Add status (will create AND)
    filter = FilterElementBuilder.addFilter(
        filter, StatusElement('Completed', 'COMPLETED'));

    // Add HasPR
    filter = FilterElementBuilder.addFilter(filter, HasPrElement());

    // Toggle NOT on HasPR
    filter = FilterElementBuilder.toggleNot(filter!, HasPrElement());

    setState(() {
      _currentFilter = filter;
    });
  }

  void _handleRemove(FilterElement element) {
    setState(() {
      _currentFilter =
          FilterElementBuilder.removeFilter(_currentFilter, element);
      _currentFilter = FilterElementBuilder.simplify(_currentFilter);
    });
  }

  void _handleToggleNot(FilterElement element) {
    setState(() {
      _currentFilter = FilterElementBuilder.toggleNot(_currentFilter, element);
      _currentFilter = FilterElementBuilder.simplify(_currentFilter);
    });
  }

  void _handleTap(FilterElement element) {
    // Show menu with options
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tapped: ${element.runtimeType}'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _addUnreadFilter() {
    setState(() {
      _currentFilter = FilterElementBuilder.addFilter(
        _currentFilter,
        LabelElement('Unread', 'unread'),
      );
    });
  }

  void _addUpdatedFilter() {
    setState(() {
      _currentFilter = FilterElementBuilder.addFilter(
        _currentFilter,
        LabelElement('Updated', 'updated'),
      );
    });
  }

  void _addTextFilter() {
    setState(() {
      _currentFilter = FilterElementBuilder.addFilter(
        _currentFilter,
        TextElement('search term'),
      );
    });
  }

  void _reset() {
    setState(() {
      _currentFilter = null;
      _buildDemoFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Element Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset to demo filter',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hierarchical Filter Visualization',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This demonstrates how filters are rendered with proper nesting.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Filter display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _currentFilter != null
                  ? FilterElementWidget(
                      element: _currentFilter,
                      onRemove: _handleRemove,
                      onToggleNot: _handleToggleNot,
                      onTap: _handleTap,
                    )
                  : const Text(
                      'No filters',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Actions
            Text(
              'Add Filters:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _addUnreadFilter,
                  icon: const Icon(Icons.flag, size: 16),
                  label: const Text('Add Unread'),
                ),
                ElevatedButton.icon(
                  onPressed: _addUpdatedFilter,
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text('Add Updated'),
                ),
                ElevatedButton.icon(
                  onPressed: _addTextFilter,
                  icon: const Icon(Icons.text_fields, size: 16),
                  label: const Text('Add Text Search'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentFilter = FilterElementBuilder.addFilter(
                        _currentFilter,
                        StatusElement('In Progress', 'IN_PROGRESS'),
                      );
                    });
                  },
                  icon: const Icon(Icons.info, size: 16),
                  label: const Text('Add Status'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // JSON output
            ExpansionTile(
              title: const Text('JSON Representation'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _currentFilter != null
                        ? _formatJson(_currentFilter!.toJson())
                        : 'null',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.greenAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        '• Filters of the same type are grouped with OR'),
                    const Text('• Different types are combined with AND'),
                    const Text('• Click ❌ to remove a filter'),
                    const Text('• Click ↶ on NOT to unwrap'),
                    const Text('• Nested boxes show hierarchical structure'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }
}
