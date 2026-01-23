import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_provider.dart';
import '../../services/source_provider.dart';
import '../../models.dart';
import 'bulk_source_selector_dialog.dart';

class GroupManagementDialog extends StatefulWidget {
  const GroupManagementDialog({super.key});

  @override
  State<GroupManagementDialog> createState() => _GroupManagementDialogState();
}

class _GroupManagementDialogState extends State<GroupManagementDialog> {
  void _showEditGroupDialog(SourceGroup? group) {
    showDialog(
      context: context,
      builder: (context) => _GroupEditorDialog(group: group),
    );
  }

  void _deleteGroup(SourceGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete ${group.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<SettingsProvider>(context, listen: false)
                  .deleteSourceGroup(group.name);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final groups = settings.sourceGroups;

        return AlertDialog(
          title: const Text('Manage Groups'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: groups.isEmpty
                ? const Center(child: Text('No groups created.'))
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return ListTile(
                        title: Text(group.name),
                        subtitle:
                            Text('${group.sourceNames.length} repositories'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditGroupDialog(group),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteGroup(group),
                              tooltip: 'Delete',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () => _showEditGroupDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
          ],
        );
      },
    );
  }
}

class _GroupEditorDialog extends StatefulWidget {
  final SourceGroup? group;

  const _GroupEditorDialog({this.group});

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  late TextEditingController _nameController;
  List<String> _selectedSourceNames = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _selectedSourceNames = List.from(widget.group?.sourceNames ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectSources() async {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final allSources = sourceProvider.items.map((i) => i.data).toList();

    // Map selected names back to source objects if available
    final initialSelection =
        allSources.where((s) => _selectedSourceNames.contains(s.name)).toList();

    final result = await showDialog<List<Source>>(
      context: context,
      builder: (context) => BulkSourceSelectorDialog(
        availableSources: allSources,
        initialSelectedSources: initialSelection,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedSourceNames = result.map((s) => s.name).toList();
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Enforce @ prefix if desired? User prompt said "like: @dart".
    // Let's enforce it for consistency if it doesn't have it.
    // Or just let user decide. The prompt implies "@dart" is the group name.
    // I'll prepend @ if missing.
    String finalName = name;
    if (!finalName.startsWith('@')) {
      finalName = '@$finalName';
    }

    final newGroup = SourceGroup(
      name: finalName,
      sourceNames: _selectedSourceNames,
    );

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (widget.group != null) {
      // Check if name changed and conflicts?
      // For now assume update works by name, but if name changed we delete old and add new?
      // Provider has updateSourceGroup which matches by name.
      // So if I rename, I should delete old one and add new one.
      if (widget.group!.name != finalName) {
        await settings.deleteSourceGroup(widget.group!.name);
        await settings.addSourceGroup(newGroup);
      } else {
        await settings.updateSourceGroup(newGroup);
      }
    } else {
      await settings.addSourceGroup(newGroup);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.group == null ? 'Create Group' : 'Edit Group'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: '@groupname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selectedSourceNames.length} repositories selected'),
                TextButton(
                  onPressed: _selectSources,
                  child: const Text('Select Repositories'),
                ),
              ],
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
