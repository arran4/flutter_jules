import 'package:flutter/material.dart';
import '../../models/note.dart';

class NoteDialog extends StatefulWidget {
  final Note? note;

  const NoteDialog({super.key, this.note});

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Note'),
      content: TextField(
        controller: _contentController,
        maxLines: 8,
        decoration: const InputDecoration(
          hintText: 'Enter note...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final content = _contentController.text.trim();
            if (content.isEmpty) return;

            final newNote = Note(
              content: content,
              updatedDate: DateTime.now().toIso8601String(),
              version: (widget.note?.version ?? 0) + 1,
            );
            Navigator.pop(context, newNote);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
