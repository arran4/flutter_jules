import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // A more structured layout for shortcuts
    final shortcuts = {
      'New Session': 'Ctrl + N',
      'Show Shortcuts (Global)': 'Ctrl + Shift + ?',
    };

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
            rows: shortcuts.entries.map((entry) {
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
