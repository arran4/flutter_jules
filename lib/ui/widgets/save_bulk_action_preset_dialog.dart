import 'package:flutter/material.dart';

class SaveBulkActionPresetDialog extends StatefulWidget {
  const SaveBulkActionPresetDialog({super.key});

  @override
  State<SaveBulkActionPresetDialog> createState() =>
      _SaveBulkActionPresetDialogState();
}

class _SaveBulkActionPresetDialogState
    extends State<SaveBulkActionPresetDialog> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Bulk Action Preset'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'Enter a name for the preset',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
              onSaved: (value) => _name = value!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter an optional description',
              ),
              onSaved: (value) => _description = value ?? '',
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
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(context, {
                'name': _name,
                'description': _description,
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
