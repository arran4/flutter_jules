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
    final availableTags = _getAvailableTags(allTags);

    return AlertDialog(
      title: const Text('Manage Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentTagsSection(),
              const SizedBox(height: 20),
              _buildNewTagInput(),
              const SizedBox(height: 20),
              _buildAvailableTagsSection(availableTags),
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

  List<String> _getAvailableTags(List<String> allTags) {
    return allTags
        .where(
          (tag) =>
              !_currentTags.any((t) => t.toLowerCase() == tag.toLowerCase()),
        )
        .toList();
  }

  Widget _buildCurrentTagsSection() {
    return CurrentTagsSection(
      tags: _currentTags,
      onRemoveTag: _removeTag,
    );
  }

  Widget _buildNewTagInput() {
    return NewTagInput(
      controller: _newTagController,
      onSubmitted: _addNewTag,
      onAddPressed: () => _addNewTag(_newTagController.text),
    );
  }

  Widget _buildAvailableTagsSection(List<String> availableTags) {
    return AvailableTagsSection(
      availableTags: availableTags,
      onTagSelected: _addNewTag,
    );
  }

  void _removeTag(String tag) {
    setState(() {
      _currentTags.remove(tag);
    });
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

class CurrentTagsSection extends StatelessWidget {
  final List<String> tags;
  final ValueChanged<String> onRemoveTag;

  const CurrentTagsSection({
    super.key,
    required this.tags,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Tags',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          const Text('No tags yet.')
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    onDeleted: () => onRemoveTag(tag),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class NewTagInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAddPressed;

  const NewTagInput({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Add a new tag',
              border: OutlineInputBorder(),
            ),
            onSubmitted: onSubmitted,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddPressed,
        ),
      ],
    );
  }
}

class AvailableTagsSection extends StatelessWidget {
  final List<String> availableTags;
  final ValueChanged<String> onTagSelected;

  const AvailableTagsSection({
    super.key,
    required this.availableTags,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () => onTagSelected(tag),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
