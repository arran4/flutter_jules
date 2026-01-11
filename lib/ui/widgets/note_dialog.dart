import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/note.dart';

class NoteDialog extends StatefulWidget {
  final Note? note;

  const NoteDialog({super.key, this.note});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late TextEditingController _controller;
  late int _version;
  String? _updatedDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.content ?? '');
    _version = widget.note?.version ?? 0;
    _updatedDate = widget.note?.updatedDate;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final newNote = Note(
      content: _controller.text,
      updatedDate: DateTime.now().toIso8601String(),
      version: _version + 1,
    );
    Navigator.of(context).pop(newNote);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Enter your note here...',
              border: OutlineInputBorder(),
            ),
          ),
          if (_updatedDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Last updated: ${DateFormat.yMMMd().add_jm().format(DateTime.parse(_updatedDate!).toLocal())} (v$_version)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
