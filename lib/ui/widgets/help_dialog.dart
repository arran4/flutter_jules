import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/shortcut_registry.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  String _formatActivator(ShortcutActivator activator) {
    if (activator is SingleActivator) {
      final List<String> parts = [];
      if (activator.control) parts.add('Ctrl');
      if (activator.meta) parts.add('Meta');
      if (activator.alt) parts.add('Alt');
      if (activator.shift) parts.add('Shift');
      parts.add(activator.trigger.keyLabel);
      return parts.join(' + ');
    }
    return activator.toString();
  }

  @override
  Widget build(BuildContext context) {
    final registry = Provider.of<ShortcutRegistry>(context);
    final shortcuts = registry.shortcuts;
    final descriptions = registry.descriptions;

    final List<MapEntry<String, String>> rows = [];
    shortcuts.forEach((activator, intent) {
      final description = descriptions[intent] ?? intent.toString();
      rows.add(MapEntry(description, _formatActivator(activator)));
    });

    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('Shortcut')),
            ],
            rows: rows.map((entry) {
              return DataRow(cells: [
                DataCell(Text(entry.key)),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
