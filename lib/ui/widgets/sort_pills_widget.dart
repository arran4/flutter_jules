import 'package:flutter/material.dart';
import '../../models/search_filter.dart';

/// Widget for displaying and managing sort pills
class SortPillsWidget extends StatelessWidget {
  final List<SortOption> activeSorts;
  final ValueChanged<List<SortOption>> onSortsChanged;

  const SortPillsWidget({
    super.key,
    required this.activeSorts,
    required this.onSortsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort Button (Add)
          InkWell(
            onTap: () => _showAddSortMenu(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, size: 16, color: Colors.grey.shade700),
                  if (activeSorts.isEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (activeSorts.isNotEmpty)
            Container(
              height: 16,
              width: 1,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),

          // Active Sorts
          ...activeSorts.asMap().entries.map((entry) {
            final index = entry.key;
            final sort = entry.value;

            return Draggable<SortOption>(
              data: sort,
              feedback: Material(
                color: Colors.transparent,
                child: _buildSortPill(context, sort, isDragging: true),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: _buildSortPill(context, sort),
              ),
              child: DragTarget<SortOption>(
                onWillAcceptWithDetails: (details) => details.data != sort,
                onAcceptWithDetails: (details) {
                  final incoming = details.data;
                  final incomingIndex = activeSorts.indexOf(incoming);
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
                      _buildSortPill(context, sort),
                    ],
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSortPill(
    BuildContext context,
    SortOption sort, {
    bool isDragging = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Tooltip(
        message:
            "Sort by ${sort.label}. Tap to toggle direction. Drag to reorder.",
        child: InkWell(
          onTap: () => _toggleSortDirection(sort),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDragging ? Colors.grey.shade300 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
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

  void _toggleSortDirection(SortOption sort) {
    final index = activeSorts.indexOf(sort);
    if (index == -1) return;

    final newSorts = List<SortOption>.from(activeSorts);
    final newDirection = sort.direction == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
    newSorts[index] = SortOption(sort.field, newDirection);
    onSortsChanged(newSorts);
  }

  void _removeSort(SortOption sort) {
    final newSorts = List<SortOption>.from(activeSorts)..remove(sort);
    onSortsChanged(newSorts);
  }

  void _reorderSorts(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final items = List<SortOption>.from(activeSorts);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    onSortsChanged(items);
  }

  void _showAddSortMenu(BuildContext context) {
    final existingFields = activeSorts.map((s) => s.field).toSet();
    final availableFields = SortField.values
        .where((f) => !existingFields.contains(f))
        .toList();

    if (availableFields.isEmpty) return; // All fields added

    // Find the widget's position
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
        final newSorts = List<SortOption>.from(activeSorts)
          ..add(SortOption(value, SortDirection.descending));
        onSortsChanged(newSorts);
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
}
