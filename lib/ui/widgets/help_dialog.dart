import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/shortcut_registry.dart' as custom_shortcuts;

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  String _formatActivator(ShortcutActivator activator) {
    if (activator is SingleActivator) {
      final parts = <String>[];
      if (activator.control) parts.add('Ctrl');
      if (activator.alt) parts.add('Alt');
      if (activator.shift) parts.add('Shift');
      if (activator.meta) parts.add('Meta');

      String keyLabel = activator.trigger.keyLabel;
      // Special case for ? (Shift + /)
      if (activator.trigger == LogicalKeyboardKey.slash && activator.shift) {
        keyLabel = '?';
      } else if (activator.trigger == LogicalKeyboardKey.space) {
        keyLabel = 'Space';
      }

      parts.add(keyLabel.toUpperCase());
      return parts.join(' + ');
    }
    return activator.toString();
  }

  @override
  Widget build(BuildContext context) {
    final registry = Provider.of<custom_shortcuts.ShortcutRegistry>(context);
    final shortcutActions = registry.shortcutActions;
    final descriptions = registry.descriptions;

    final rows = <DataRow>[];

    shortcutActions.forEach((activator, action) {
      final description = descriptions[action];
      if (description != null) {
        rows.add(
          DataRow(
            cells: [
              DataCell(Text(description)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatActivator(activator),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
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
            rows: rows,
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
