import 'package:flutter/material.dart';
import '../../models.dart';

class MetadataViewer extends StatelessWidget {
  final List<Metadata> metadata;

  const MetadataViewer({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session Metadata'),
      content: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Key')),
            DataColumn(label: Text('Value')),
          ],
          rows: metadata
              .map(
                (m) => DataRow(
                  cells: [
                    DataCell(Text(m.key)),
                    DataCell(Text(m.value)),
                  ],
                ),
              )
              .toList(),
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
