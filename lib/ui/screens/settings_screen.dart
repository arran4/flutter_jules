import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../services/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refresh Settings'),
      ),
      body: Consumer3<SettingsProvider, DevModeProvider, AuthProvider>(
        builder: (context, settings, devMode, auth, child) {
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
                subtitle:
                    const Text('Log API requests and responses to console'),
                value: devMode.enableApiLogging,
                onChanged: (value) => devMode.toggleApiLogging(value),
              ),
              const Divider(),
              _buildSectionHeader(context, 'Authentication'),
              ListTile(
                title: const Text('Current Session'),
                subtitle: Text(auth.tokenType == TokenType.apiKey
                    ? 'API Key'
                    : 'Google Access Token'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
              ListTile(
                title: const Text('Update API Key'),
                leading: const Icon(Icons.vpn_key),
                onTap: () async {
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
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
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
                        const SnackBar(
                            content: Text('API Key updated successfully')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                title:
                    const Text('Sign Out', style: TextStyle(color: Colors.red)),
                leading: const Icon(Icons.logout, color: Colors.red),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sign Out')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close settings
                      auth.logout();
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
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
      case ListRefreshPolicy.quick:
        return 'Quick Refresh';
      case ListRefreshPolicy.full:
        return 'Full Refresh';
    }
  }
}
