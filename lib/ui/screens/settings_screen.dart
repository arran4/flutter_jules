import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/refresh_schedule.dart';
import '../../services/settings_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body:
          Consumer4<
            SettingsProvider,
            DevModeProvider,
            AuthProvider,
            GithubProvider
          >(
            builder: (context, settings, devMode, auth, github, child) {
              return ListView(
                children: [
                  _buildSectionHeader(context, 'Session Updates'),
                  _buildSessionDropdown(
                    context,
                    title: 'On Session Open',
                    value: settings.refreshOnOpen,
                    onChanged: settings.setRefreshOnOpen,
                  ),
                  _buildSessionDropdown(
                    context,
                    title: 'On Message Sent',
                    value: settings.refreshOnMessage,
                    onChanged: settings.setRefreshOnMessage,
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'List Updates'),
                  _buildListDropdown(
                    context,
                    title: 'On Return to List',
                    value: settings.refreshOnReturn,
                    onChanged: settings.setRefreshOnReturn,
                  ),
                  _buildListDropdown(
                    context,
                    title: 'On Session Created',
                    value: settings.refreshOnCreate,
                    onChanged: settings.setRefreshOnCreate,
                  ),
                  const Divider(),
                  _buildAutomaticRefreshSection(context, settings),
                  const Divider(),
                  _buildSectionHeader(context, 'Performance'),
                  ListTile(
                    title: const Text('Sessions Page Size'),
                    subtitle: Text('${settings.sessionPageSize} items'),
                  ),
                  Slider(
                    value: settings.sessionPageSize.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: settings.sessionPageSize.toString(),
                    onChanged: (double value) {
                      settings.setSessionPageSize(value.toInt());
                    },
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Developer'),
                  SwitchListTile(
                    title: const Text('Developer Mode'),
                    subtitle: const Text('Enable advanced features and stats'),
                    value: devMode.isDevMode,
                    onChanged: (value) => devMode.toggleDevMode(value),
                  ),
                  SwitchListTile(
                    title: const Text('API Logging'),
                    subtitle: const Text(
                      'Log API requests and responses to console',
                    ),
                    value: devMode.enableApiLogging,
                    onChanged: (value) => devMode.toggleApiLogging(value),
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'Authentication'),
                  ListTile(
                    title: const Text('Current Session'),
                    subtitle: Text(
                      auth.tokenType == TokenType.apiKey
                          ? 'API Key'
                          : 'Google Access Token',
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  ListTile(
                    title: const Text('Update API Key'),
                    leading: const Icon(Icons.vpn_key),
                    onTap: () => _showApiKeyDialog(context, auth),
                  ),
                  ListTile(
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    leading: const Icon(Icons.logout, color: Colors.red),
                    onTap: () => _showSignOutDialog(context, auth),
                  ),
                  const Divider(),
                  _buildSectionHeader(context, 'GitHub'),
                  ListTile(
                    title: const Text('Personal Access Token'),
                    subtitle: Text(
                      github.apiKey != null
                          ? '********${github.apiKey!.substring(github.apiKey!.length - 4)}'
                          : 'Not set',
                    ),
                    leading: const Icon(Icons.code),
                    onTap: () => _showGitHubKeyDialog(context, github),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _showGitHubKeyDialog(
    BuildContext context,
    GithubProvider github,
  ) async {
    final controller = TextEditingController();
    final newKey = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter GitHub PAT'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Personal Access Token',
            hintText: 'Paste your token here',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newKey != null && newKey.isNotEmpty) {
      if (!context.mounted) return;
      await github.setApiKey(newKey);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub token updated successfully')),
        );
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAutomaticRefreshSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Automatic Refresh',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showScheduleDialog(context, settings),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: settings.schedules.length,
          itemBuilder: (context, index) {
            final schedule = settings.schedules[index];
            return ListTile(
              title: Text(schedule.name),
              subtitle: Text(
                'Every ${schedule.intervalInMinutes} mins, ${_formatListPolicy(schedule.refreshPolicy)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: schedule.isEnabled,
                    onChanged: (value) {
                      schedule.isEnabled = value;
                      settings.updateSchedule(schedule);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _showScheduleDialog(context, settings, schedule),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => settings.deleteSchedule(schedule.id),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showScheduleDialog(
    BuildContext context,
    SettingsProvider settings, [
    RefreshSchedule? schedule,
  ]) {
    final isEditing = schedule != null;
    final nameController = TextEditingController(text: schedule?.name ?? '');
    final intervalController = TextEditingController(
      text: schedule?.intervalInMinutes.toString() ?? '',
    );
    var refreshPolicy = schedule?.refreshPolicy ?? ListRefreshPolicy.quick;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Schedule' : 'Add Schedule'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Interval (minutes)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<ListRefreshPolicy>(
                    // ignore: deprecated_member_use
                    value: refreshPolicy,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          refreshPolicy = value;
                        });
                      }
                    },
                    items: ListRefreshPolicy.values.map((policy) {
                      return DropdownMenuItem(
                        value: policy,
                        child: Text(_formatListPolicy(policy)),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final interval = int.tryParse(intervalController.text);
                if (interval == null) {
                  // Show an error message if the interval is not a valid number.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter a valid number for the interval.',
                      ),
                    ),
                  );
                  return;
                }
                final newSchedule = RefreshSchedule(
                  id: schedule?.id,
                  name: nameController.text,
                  intervalInMinutes: interval,
                  refreshPolicy: refreshPolicy,
                  isEnabled: schedule?.isEnabled ?? true,
                );

                if (isEditing) {
                  settings.updateSchedule(newSchedule);
                } else {
                  settings.addSchedule(newSchedule);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showApiKeyDialog(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final controller = TextEditingController();
    final newKey = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Key',
            hintText: 'Paste your API key here',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newKey != null && newKey.isNotEmpty) {
      if (!context.mounted) return;
      await auth.setToken(newKey, TokenType.apiKey);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key updated successfully')),
        );
      }
    }
  }

  Future<void> _showSignOutDialog(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (context.mounted) {
        Navigator.pop(context); // Close settings
        auth.logout();
      }
    }
  }

  Widget _buildSessionDropdown(
    BuildContext context, {
    required String title,
    required SessionRefreshPolicy value,
    required Function(SessionRefreshPolicy) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<SessionRefreshPolicy>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        items: SessionRefreshPolicy.values.map((policy) {
          return DropdownMenuItem(
            value: policy,
            child: Text(_formatSessionPolicy(policy)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListDropdown(
    BuildContext context, {
    required String title,
    required ListRefreshPolicy value,
    required Function(ListRefreshPolicy) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<ListRefreshPolicy>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        items: ListRefreshPolicy.values.map((policy) {
          return DropdownMenuItem(
            value: policy,
            child: Text(_formatListPolicy(policy)),
          );
        }).toList(),
      ),
    );
  }

  String _formatSessionPolicy(SessionRefreshPolicy policy) {
    switch (policy) {
      case SessionRefreshPolicy.none:
        return 'None';
      case SessionRefreshPolicy.shallow:
        return 'Quick Refresh';
      case SessionRefreshPolicy.full:
        return 'Full Refresh';
    }
  }

  String _formatListPolicy(ListRefreshPolicy policy) {
    switch (policy) {
      case ListRefreshPolicy.none:
        return 'None';
      case ListRefreshPolicy.dirty:
        return 'Dirty Only';
      case ListRefreshPolicy.watched:
        return 'Watched Only';
      case ListRefreshPolicy.quick:
        return 'Quick Refresh';
      case ListRefreshPolicy.full:
        return 'Full Refresh';
    }
  }
}
