import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../models/session.dart';
import '../../services/session_provider.dart';
import '../../services/tags_provider.dart';

class TagManagementDialog extends StatefulWidget {
  final Session session;

  const TagManagementDialog({super.key, required this.session});

  @override
  TagManagementDialogState createState() => TagManagementDialogState();
}

class TagManagementDialogState extends State<TagManagementDialog> {
  final _newTagController = TextEditingController();
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.session.tags ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final allTags = Provider.of<TagsProvider>(context).allTags;
    final availableTags = allTags
        .where(
          (tag) =>
              !_currentTags.any((t) => t.toLowerCase() == tag.toLowerCase()),
        )
        .toList();

    return AlertDialog(
      title: const Text('Manage Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentTags(),
              const SizedBox(height: 20),
              _buildNewTagInput(),
              const SizedBox(height: 20),
              _buildAvailableTags(availableTags),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _saveTags, child: const Text('Save')),
      ],
    );
  }

  Widget _buildCurrentTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Tags',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_currentTags.isEmpty)
          const Text('No tags yet.')
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _currentTags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    onDeleted: () {
                      setState(() {
                        _currentTags.remove(tag);
                      });
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildNewTagInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _newTagController,
            decoration: const InputDecoration(
              labelText: 'Add a new tag',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _addNewTag,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _addNewTag(_newTagController.text),
        ),
      ],
    );
  }

  Widget _buildAvailableTags(List<String> availableTags) {
    if (availableTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Tags',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: availableTags
              .map(
                (tag) => ActionChip(
                  label: Text('#$tag'),
                  onPressed: () {
                    _addNewTag(tag);
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _addNewTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty &&
        !_currentTags.any((t) => t.toLowerCase() == trimmedTag.toLowerCase())) {
      setState(() {
        _currentTags.add(trimmedTag);
        _currentTags.sort(compareAsciiLowerCase);
      });
    }
    _newTagController.clear();
  }

  void _saveTags() {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    sessionProvider.updateSessionTags(widget.session, _currentTags);
    Navigator.of(context).pop();
  }
}
