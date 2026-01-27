import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/prompt_template_provider.dart';
import '../../models/prompt_template.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _useTemplate(String content) {
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        width: size.width * 0.9,
        height: size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Select Prompt',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Templates'),
                Tab(text: 'Recent'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TemplatesTab(onUse: _useTemplate),
                  _RecentTab(onUse: _useTemplate),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  final Function(String) onUse;

  const _TemplatesTab({required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Consumer<PromptTemplateProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final builtIn = provider.builtInTemplates;
        final custom = provider.customTemplates;

        return ListView(
          children: [
            _buildSectionHeader(
              context,
              'Custom Templates',
              trailing: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create New Template',
                onPressed: () => _showEditDialog(context),
              ),
            ),
            if (custom.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No custom templates yet.'),
              ),
            ...custom.map((t) => _buildTemplateItem(context, t, provider)),
            const Divider(height: 32),
            _buildSectionHeader(context, 'Inbuilt Templates'),
            ...builtIn.map((t) => _buildTemplateItem(context, t, provider)),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildTemplateItem(
    BuildContext context,
    PromptTemplate template,
    PromptTemplateProvider provider,
  ) {
    final isEnabled =
        !template.isBuiltIn || provider.isBuiltInEnabled(template.id);
    final theme = Theme.of(context);

    if (template.isBuiltIn && !isEnabled) {
      // Show disabled inbuilt item (maybe slightly faded with enable button)
      return ListTile(
        title: Text(
          template.name,
          style: TextStyle(color: theme.disabledColor),
        ),
        subtitle: Text(
          'Disabled',
          style: TextStyle(color: theme.disabledColor),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.visibility_off),
          tooltip: 'Enable',
          onPressed: () => provider.toggleBuiltIn(template.id, true),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      child: ExpansionTile(
        title: Text(template.name),
        subtitle: template.description != null
            ? Text(
                template.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              template.content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (template.isBuiltIn) ...[
                IconButton(
                  icon: const Icon(Icons.visibility),
                  tooltip: 'Disable',
                  onPressed: () => provider.toggleBuiltIn(template.id, false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy to Custom'),
                  onPressed: () => _showEditDialog(
                    context,
                    initialName: '${template.name} (Copy)',
                    initialDesc: template.description,
                    initialContent: template.content,
                  ),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () => _showEditDialog(context, template: template),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  color: theme.colorScheme.error,
                  onPressed: () => _confirmDelete(context, provider, template),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Use'),
                onPressed: () => onUse(template.content),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context, {
    PromptTemplate? template,
    String? initialName,
    String? initialDesc,
    String? initialContent,
  }) async {
    final nameController = TextEditingController(
      text: template?.name ?? initialName ?? '',
    );
    final descController = TextEditingController(
      text: template?.description ?? initialDesc ?? '',
    );
    final contentController = TextEditingController(
      text: template?.content ?? initialContent ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template == null ? 'Create Template' : 'Edit Template'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  contentController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final provider = Provider.of<PromptTemplateProvider>(
        context,
        listen: false,
      );
      if (template != null) {
        // Edit existing
        final newTemplate = PromptTemplate(
          id: template.id,
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
          content: contentController.text,
          isBuiltIn: false,
        );
        provider.updateCustomTemplate(newTemplate);
      } else {
        // Create new
        final newTemplate = PromptTemplate(
          id: const Uuid().v4(),
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
          content: contentController.text,
          isBuiltIn: false,
        );
        provider.addCustomTemplate(newTemplate);
      }
    }
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
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

class _RecentTab extends StatelessWidget {
  final Function(String) onUse;

  const _RecentTab({required this.onUse});

  @override
  Widget build(BuildContext context) {
    return Consumer<PromptTemplateProvider>(
      builder: (context, provider, _) {
        final recents = provider.recentPrompts;

        if (recents.isEmpty) {
          return const Center(child: Text('No recent prompts.'));
        }

        return ListView.builder(
          itemCount: recents.length,
          itemBuilder: (context, index) {
            final prompt = recents[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(
                  prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_as),
                      tooltip: 'Save as Template',
                      onPressed: () => _saveAsTemplate(context, prompt),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Discard',
                      onPressed: () => provider.deleteRecentPrompt(prompt),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => onUse(prompt),
                      child: const Text('Reuse'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAsTemplate(BuildContext context, String prompt) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Recent Prompt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final provider = Provider.of<PromptTemplateProvider>(
        context,
        listen: false,
      );
      final newTemplate = PromptTemplate(
        id: const Uuid().v4(),
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty
            ? null
            : descController.text.trim(),
        content: prompt,
        isBuiltIn: false,
      );
      provider.addCustomTemplate(newTemplate);
    }
  }
}
