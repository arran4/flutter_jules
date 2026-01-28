import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../services/prompt_template_provider.dart';

class PromptTemplateSelectorDialog extends StatefulWidget {
  const PromptTemplateSelectorDialog({super.key});

  @override
  State<PromptTemplateSelectorDialog> createState() =>
      _PromptTemplateSelectorDialogState();
}

class _PromptTemplateSelectorDialogState
    extends State<PromptTemplateSelectorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showDisabledInbuilt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    'Prompt Templates',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search and Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search templates...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.toLowerCase();
                            });
                          },
                        ),
                      ),
                      if (_tabController.index == 1) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _showEditor(context),
                          icon: const Icon(Icons.add),
                          label: const Text('New'),
                        ),
                      ],
                      if (_tabController.index == 2) ...[
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Show Disabled'),
                          selected: _showDisabledInbuilt,
                          onSelected: (val) {
                            setState(() {
                              _showDisabledInbuilt = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).primaryColor,
                    onTap: (index) => setState(() {}),
                    tabs: const [
                      Tab(text: 'Recent'),
                      Tab(text: 'Saved'),
                      Tab(text: 'Inbuilt'),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Consumer<PromptTemplateProvider>(
                builder: (context, provider, child) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecentList(provider),
                      _buildSavedList(provider),
                      _buildInbuiltList(provider),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(PromptTemplateProvider provider) {
    final templates = provider.recentPrompts.where((t) {
      return t.content.toLowerCase().contains(_searchQuery);
    }).toList();

    if (templates.isEmpty) {
      return const Center(child: Text('No recent prompts found.'));
    }

    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              template.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              template.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectTemplate(template),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save to Custom',
                  onPressed: () => _showEditor(context, template: template),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Discard',
                  onPressed: () => provider.deleteRecentPrompt(template.id),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _selectTemplate(template),
                  child: const Text('Reuse'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedList(PromptTemplateProvider provider) {
    final templates = provider.customTemplates.where((t) {
      return t.name.toLowerCase().contains(_searchQuery) ||
          t.content.toLowerCase().contains(_searchQuery);
    }).toList();

    if (templates.isEmpty) {
      return const Center(child: Text('No saved templates found.'));
    }

    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              template.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectTemplate(template),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () =>
                      _showEditor(context, template: template, isEditing: true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context, provider, template),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _selectTemplate(template),
                  child: const Text('Use'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInbuiltList(PromptTemplateProvider provider) {
    final templates = provider.allBuiltInTemplates.where((t) {
      return t.name.toLowerCase().contains(_searchQuery) ||
          t.content.toLowerCase().contains(_searchQuery);
    }).toList();

    if (templates.isEmpty) {
      return const Center(child: Text('No inbuilt templates found.'));
    }

    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        final isDisabled = provider.isBuiltInDisabled(template.id);

        if (isDisabled && !_showDisabledInbuilt) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: isDisabled ? 0.6 : 1.0,
          child: Card(
            color: isDisabled
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
                : null,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(
                isDisabled ? Icons.visibility_off : Icons.stars,
                color: isDisabled ? Colors.grey : Colors.amber,
              ),
              title: Text(
                template.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                template.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: isDisabled ? null : () => _selectTemplate(template),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isDisabled ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: isDisabled ? 'Enable' : 'Disable',
                    onPressed: () =>
                        provider.toggleBuiltIn(template.id, !isDisabled),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy to Custom',
                    onPressed: () => _showEditor(context, template: template),
                  ),
                  if (!isDisabled) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _selectTemplate(template),
                      child: const Text('Use'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectTemplate(PromptTemplate template) {
    Navigator.pop(context, template.content);
  }

  void _showEditor(
    BuildContext context, {
    PromptTemplate? template,
    bool isEditing = false,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          _TemplateEditorDialog(template: template, isEditing: isEditing),
    );
  }

  void _confirmDelete(
    BuildContext context,
    PromptTemplateProvider provider,
    PromptTemplate template,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteCustomTemplate(template.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  final PromptTemplate? template;
  final bool isEditing;

  const _TemplateEditorDialog({this.template, this.isEditing = false});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.isEditing
          ? widget.template?.name
          : (widget.template != null ? 'Copy of ${widget.template!.name}' : ''),
    );
    _contentController = TextEditingController(
      text: widget.template?.content ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Template' : 'New Template'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
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
            final name = _nameController.text.trim();
            final content = _contentController.text.trim();

            if (name.isEmpty || content.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter name and content')),
              );
              return;
            }

            final provider = Provider.of<PromptTemplateProvider>(
              context,
              listen: false,
            );

            if (widget.isEditing && widget.template != null) {
              provider.updateCustomTemplate(widget.template!.id, name, content);
            } else {
              provider.addCustomTemplate(name, content);
            }

            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
