import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/bulk_action_preset.dart';
import '../../services/bulk_action_preset_provider.dart';

class BulkActionPresetManagerScreen extends StatefulWidget {
  const BulkActionPresetManagerScreen({super.key});

  @override
  State<BulkActionPresetManagerScreen> createState() =>
      _BulkActionPresetManagerScreenState();
}

class _BulkActionPresetManagerScreenState
    extends State<BulkActionPresetManagerScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bulk Action Presets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _importPresets(context),
            tooltip: 'Import from File/Clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _exportPresets(context),
            tooltip: 'Export All to Clipboard/File',
          ),
        ],
      ),
      body: Consumer<BulkActionPresetProvider>(
        builder: (context, provider, child) {
          final activePresets = provider.presets.where((p) {
            if (_searchQuery.isEmpty) return true;
            return p.name.toLowerCase().contains(_searchQuery) ||
                (p.description?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();

          final restorablePresets = provider.getRestorableSystemPresets().where(
            (p) {
              if (_searchQuery.isEmpty) return true;
              return p.name.toLowerCase().contains(_searchQuery);
            },
          ).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search presets...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderPreset(oldIndex, newIndex);
                  },
                  children: [
                    if (activePresets.isNotEmpty) ...[
                      const Padding(
                        key: ValueKey('active_header'),
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Active Presets',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      for (final p in activePresets)
                        _buildActiveTile(context, provider, p),
                    ],
                    if (restorablePresets.isNotEmpty) ...[
                      const Padding(
                        key: ValueKey('restorable_header'),
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'Deleted System Presets',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      for (final p in restorablePresets)
                        _buildRestorableTile(context, provider, p),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewPreset(context),
        tooltip: 'Create New Preset',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActiveTile(
    BuildContext context,
    BulkActionPresetProvider provider,
    BulkActionPreset preset,
  ) {
    final isSystem = provider.isSystemPreset(preset.name);

    return Card(
      key: ValueKey(preset.name),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          isSystem ? Icons.stars : Icons.playlist_play,
          color: isSystem ? Colors.amber : Colors.blue,
        ),
        title: Text(
          preset.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          preset.description ?? 'No description',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _showPresetEditor(context, preset),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSystem)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showPresetEditor(context, preset),
                tooltip: 'Edit',
              ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deletePreset(context, preset),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestorableTile(
    BuildContext context,
    BulkActionPresetProvider provider,
    BulkActionPreset preset,
  ) {
    return Card(
      key: ValueKey(preset.name),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey.shade100,
      child: ListTile(
        leading: const Icon(Icons.restore_from_trash, color: Colors.grey),
        title: Text(preset.name, style: const TextStyle(color: Colors.grey)),
        subtitle: const Text("Deleted (System Preset)"),
        trailing: FilledButton.icon(
          label: const Text("Restore"),
          icon: const Icon(Icons.refresh, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            await provider.restoreSystemPreset(preset.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Restored "${preset.name}"')),
              );
            }
          },
        ),
      ),
    );
  }

  void _createNewPreset(BuildContext context) {
    _showPresetEditor(context, null);
  }

  void _showPresetEditor(BuildContext context, BulkActionPreset? existing) {
    final isSystem = existing != null &&
        context.read<BulkActionPresetProvider>().isSystemPreset(existing.name);

    showDialog(
      context: context,
      builder: (dialogContext) =>
          _PresetEditorDialog(existing: existing, isReadOnly: isSystem),
    );
  }

  void _deletePreset(BuildContext context, BulkActionPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Are you sure you want to delete "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BulkActionPresetProvider>().deletePreset(
                    preset.name,
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "${preset.name}" deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportPresets(BuildContext context) {
    final provider = context.read<BulkActionPresetProvider>();
    final jsonString = provider.exportToJson();
    _showExportDialog(context, jsonString, title: 'Export All Presets');
  }

  void _showExportDialog(
    BuildContext context,
    String jsonString, {
    required String title,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Copy to clipboard or save to file:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard!')),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _importPresets(BuildContext context) {
    final controller = TextEditingController();
    bool merge = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Presets'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste JSON data from clipboard or file:'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Paste JSON here...',
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: merge,
                      onChanged: (value) => setState(() => merge = value!),
                    ),
                    const Expanded(
                      child: Text(
                        'Merge with existing presets (uncheck to replace all)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final jsonString = controller.text.trim();
                if (jsonString.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please paste JSON data')),
                  );
                  return;
                }

                try {
                  await context.read<BulkActionPresetProvider>().importFromJson(
                        jsonString,
                        merge: merge,
                      );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            merge
                                ? 'Presets imported and merged!'
                                : 'Presets imported (replaced all)!',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetEditorDialog extends StatefulWidget {
  final BulkActionPreset? existing;
  final bool isReadOnly;

  const _PresetEditorDialog({required this.existing, required this.isReadOnly});

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _filterController;
  late TextEditingController _scriptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _filterController = TextEditingController(
      text: widget.existing?.filterExpression ?? '',
    );
    _scriptController = TextEditingController(
      text: widget.existing?.actionScript ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Preset' : 'Edit Preset'),
      content: SizedBox(
        width: 600,
        height: 600,
        child: SingleChildScrollView(
          child: _PresetEditorForm(
            nameController: _nameController,
            descController: _descController,
            filterController: _filterController,
            scriptController: _scriptController,
            isReadOnly: widget.isReadOnly,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (!widget.isReadOnly)
          FilledButton.icon(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }

              final provider = context.read<BulkActionPresetProvider>();
              final newPreset = BulkActionPreset(
                name: name,
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                filterExpression: _filterController.text.trim(),
                actionScript: _scriptController.text.trim(),
              );

              if (widget.existing == null) {
                provider.addPreset(newPreset);
              } else {
                provider.updatePreset(widget.existing!.name, newPreset);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Preset "$name" saved')));
            },
            label: const Text('Save Preset'),
            icon: const Icon(Icons.save),
          ),
      ],
    );
  }
}

class _PresetEditorForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController filterController;
  final TextEditingController scriptController;
  final bool isReadOnly;

  const _PresetEditorForm({
    required this.nameController,
    required this.descController,
    required this.filterController,
    required this.scriptController,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Preset Name*',
            border: OutlineInputBorder(),
          ),
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 24),
        const Text(
          'Filter Expression',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: filterController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g., is:unread has:pr',
          ),
          maxLines: 2,
          enabled: !isReadOnly,
        ),
        const SizedBox(height: 24),
        const Text(
          'Action Script',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: scriptController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g., @wait 1s\nopenPrInBrowser\nmarkAsRead',
          ),
          maxLines: 8,
          enabled: !isReadOnly,
        ),
      ],
    );
  }
}
