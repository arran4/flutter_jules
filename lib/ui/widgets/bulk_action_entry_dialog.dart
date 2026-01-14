import 'package:flutter/material.dart';
import 'bulk_action_dialog.dart';
import 'bulk_action_preset_dialog.dart';
import '../../models/search_filter.dart';
import '../../models/filter_element.dart';

class BulkActionEntryDialog extends StatelessWidget {
  final FilterElement? currentFilterTree;
  final List<SortOption> currentSorts;
  final List<FilterToken> availableSuggestions;
  final String mainSearchText;

  const BulkActionEntryDialog({
    super.key,
    required this.currentFilterTree,
    required this.currentSorts,
    required this.availableSuggestions,
    required this.mainSearchText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Actions'),
      content: const Text('Choose how you want to run a bulk action.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => BulkActionDialog(
                currentFilterTree: currentFilterTree,
                currentSorts: currentSorts,
                availableSuggestions: availableSuggestions,
                mainSearchText: mainSearchText,
              ),
            );
          },
          child: const Text('One-Time Action'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (_) => const BulkActionPresetDialog(),
            );
          },
          child: const Text('Run Preset'),
        ),
      ],
    );
  }
}