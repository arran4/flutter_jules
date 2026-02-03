import 'package:flutter/material.dart';
import 'package:flutter_jules/ui/screens/activity_log_screen.dart';
import 'package:provider/provider.dart';
import '../themes.dart';
import '../../models.dart';
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
      body: Consumer4<SettingsProvider, DevModeProvider, AuthProvider,
          GithubProvider>(
        builder: (context, settings, devMode, auth, github, child) {
          return ListView(
            children: [
              _buildSessionUpdatesSection(context, settings),
              const Divider(),
              _buildListUpdatesSection(context, settings),
              const Divider(),
              _buildRefreshActionsSection(context, settings),
              const Divider(),
              _buildAppearanceSection(context, settings),
              const Divider(),
              _buildSourceListSection(context, settings),
              _buildKeybindingsSection(context, settings),
              const Divider(),
              _buildAutomaticRefreshSection(context, settings),
              const Divider(),
              _buildNotificationsSection(context, settings),
              const Divider(),
              _buildSystemTraySection(context, settings),
              const Divider(),
              _buildPerformanceSection(context, settings),
              const Divider(),
              _buildDiagnosticsSection(context),
              const Divider(),
              _buildDeveloperSection(context, settings, devMode),
              const Divider(),
              _buildAuthenticationSection(context, auth),
              const Divider(),
              _buildGitHubSection(context, settings, github),
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
      builder: (context) {
        bool isTesting = false;
        String? testResult;
        Color? resultColor;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter GitHub PAT'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Personal Access Token',
                      hintText: 'Paste your token here',
                    ),
                    obscureText: true,
                  ),
                  if (isTesting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: LinearProgressIndicator(),
                    ),
                  if (testResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        testResult!,
                        style: TextStyle(color: resultColor),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final token = controller.text.trim();
                          if (token.isEmpty) return;

                          setState(() {
                            isTesting = true;
                            testResult = null;
                          });

                          try {
                            final profile = await github.validateToken(token);
                            if (context.mounted) {
                              setState(() {
                                isTesting = false;
                                if (profile != null) {
                                  testResult =
                                      "Success! Logged in as ${profile['login']}";
                                  resultColor = Colors.green;
                                } else {
                                  testResult = "Invalid Token or Scope";
                                  resultColor = Colors.red;
                                }
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                isTesting = false;
                                testResult = "Error: $e";
                                resultColor = Colors.red;
                              });
                            }
                          }
                        },
                  child: const Text("Test"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildSessionUpdatesSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        _buildRulesSection(context, settings),
      ],
    );
  }

  Widget _buildRulesSection(BuildContext context, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Unread Rules',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showRuleEditor(context, settings),
              ),
            ],
          ),
        ),
        if (settings.unreadRules.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'No rules defined. Only direct session progression will mark sessions as unread.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ...settings.unreadRules.map((rule) {
          return ListTile(
            title: Text(rule.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: rule.enabled,
                  onChanged: (val) {
                    settings.updateUnreadRule(rule.copyWith(enabled: val));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showRuleEditor(context, settings, rule),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => settings.deleteUnreadRule(rule.id),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showRuleEditor(
    BuildContext context,
    SettingsProvider settings, [
    UnreadRule? existingRule,
  ]) {
    final isEditing = existingRule != null;
    var type = existingRule?.type ?? RuleType.contentUpdate;
    var action = existingRule?.action ?? RuleAction.markUnread;
    final fromController = TextEditingController(text: existingRule?.fromValue);
    final toController = TextEditingController(text: existingRule?.toValue);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Rule' : 'Add Rule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<RuleType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                      ),
                      items: RuleType.values.map((t) {
                        String label;
                        switch (t) {
                          case RuleType.prStatus:
                            label = 'PR Status Change';
                            break;
                          case RuleType.ciStatus:
                            label = 'CI Status Change';
                            break;
                          // case RuleType.sessionState:
                          //   label = 'Session State Change';
                          //   break;
                          case RuleType.contentUpdate:
                            label = 'Content Update (Generic)';
                            break;
                        }
                        return DropdownMenuItem(value: t, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => type = val);
                      },
                    ),
                    if (type != RuleType.contentUpdate) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: fromController,
                        decoration: const InputDecoration(
                          labelText: 'From Value (Optional)',
                          hintText: 'Any if empty',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: toController,
                        decoration: const InputDecoration(
                          labelText: 'To Value (Optional)',
                          hintText: 'Any if empty',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RuleAction>(
                      initialValue: action,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: RuleAction.values.map((a) {
                        String label;
                        switch (a) {
                          case RuleAction.markUnread:
                            label = 'Mark Unread';
                            break;
                          case RuleAction.markRead:
                            label = 'Mark Read';
                            break;
                          case RuleAction.doNothing:
                            label = 'Do Nothing';
                            break;
                        }
                        return DropdownMenuItem(value: a, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => action = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final rule = UnreadRule(
                      id: existingRule?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      type: type,
                      action: action,
                      fromValue: fromController.text.isEmpty
                          ? null
                          : fromController.text,
                      toValue:
                          toController.text.isEmpty ? null : toController.text,
                      enabled: existingRule?.enabled ?? true,
                    );
                    if (isEditing) {
                      settings.updateUnreadRule(rule);
                    } else {
                      settings.addUnreadRule(rule);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildListUpdatesSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'List Updates'),
        _buildListDropdown(
          context,
          title: 'On Application Start',
          value: settings.refreshOnAppStart,
          onChanged: settings.setRefreshOnAppStart,
        ),
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
      ],
    );
  }

  Widget _buildRefreshActionsSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Refresh Actions in App Bar'),
        ...RefreshButtonAction.values.map((action) {
          return CheckboxListTile(
            title: Text(_formatRefreshAction(action)),
            value: settings.appBarRefreshActions.contains(action),
            onChanged: (value) {
              final current = Set<RefreshButtonAction>.from(
                settings.appBarRefreshActions,
              );
              if (value == true) {
                current.add(action);
              } else {
                current.remove(action);
              }
              settings.setAppBarRefreshActions(current);
            },
          );
        }),
      ],
    );
  }

  String _formatRefreshAction(RefreshButtonAction action) {
    switch (action) {
      case RefreshButtonAction.refresh:
        return 'Refresh (Quick)';
      case RefreshButtonAction.fullRefresh:
        return 'Full Refresh';
      case RefreshButtonAction.refreshDirty:
        return 'Refresh Dirty Sessions';
    }
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Appearance'),
        _buildThemeModeDropdown(context, settings),
        _buildThemeTypeDropdown(context, settings),
        _buildFabDropdown(
          context,
          title: 'New Session Button',
          value: settings.fabVisibility,
          onChanged: settings.setFabVisibility,
        ),
      ],
    );
  }

  Widget _buildSourceListSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Source List'),
        SwitchListTile(
          title: const Text('Hide archived and read-only sources'),
          subtitle: const Text(
            'Hide sources that are marked as archived or read-only.',
          ),
          value: settings.hideArchivedAndReadOnly,
          onChanged: (value) => settings.setHideArchivedAndReadOnly(value),
        ),
      ],
    );
  }

  Widget _buildKeybindingsSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Keybindings'),
        _buildKeybindingDropdown<MessageSubmitAction>(
          context,
          title: 'Enter',
          value: settings.enterKeyAction,
          onChanged: settings.setEnterKeyAction,
          values: MessageSubmitAction.values,
          formatter: _formatMessageSubmitAction,
        ),
        _buildKeybindingDropdown<MessageSubmitAction>(
          context,
          title: 'Shift+Enter',
          value: settings.shiftEnterKeyAction,
          onChanged: settings.setShiftEnterKeyAction,
          values: MessageSubmitAction.values,
          formatter: _formatMessageSubmitAction,
        ),
        _buildKeybindingDropdown<MessageSubmitAction>(
          context,
          title: 'Ctrl+Enter',
          value: settings.ctrlEnterKeyAction,
          onChanged: settings.setCtrlEnterKeyAction,
          values: MessageSubmitAction.values,
          formatter: _formatMessageSubmitAction,
        ),
        _buildKeybindingDropdown<MessageSubmitAction>(
          context,
          title: 'Ctrl+Shift+Enter',
          value: settings.ctrlShiftEnterKeyAction,
          onChanged: settings.setCtrlShiftEnterKeyAction,
          values: MessageSubmitAction.values,
          formatter: _formatMessageSubmitAction,
        ),
        _buildKeybindingDropdown<EscKeyAction>(
          context,
          title: 'Escape',
          value: settings.escKeyAction,
          onChanged: settings.setEscKeyAction,
          values: EscKeyAction.values,
          formatter: _formatEscKeyAction,
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Notifications'),
        SwitchListTile(
          title: const Text('Task Needs Attention'),
          subtitle: const Text(
            'Receive a notification when a task requires your input.',
          ),
          value: settings.notifyOnAttention,
          onChanged: (value) => settings.setNotifyOnAttention(value),
        ),
        SwitchListTile(
          title: const Text('Task Completes'),
          subtitle: const Text(
            'Receive a notification when a task is completed.',
          ),
          value: settings.notifyOnCompletion,
          onChanged: (value) => settings.setNotifyOnCompletion(value),
        ),
        SwitchListTile(
          title: const Text('Watched Task Updates'),
          subtitle: const Text(
            'Receive a notification for any update on a task you are watching.',
          ),
          value: settings.notifyOnWatch,
          onChanged: (value) => settings.setNotifyOnWatch(value),
        ),
        SwitchListTile(
          title: const Text('Task Fails'),
          subtitle: const Text('Receive a notification when a task fails.'),
          value: settings.notifyOnFailure,
          onChanged: (value) => settings.setNotifyOnFailure(value),
        ),
        SwitchListTile(
          title: const Text('Refresh Started'),
          subtitle: const Text('Receive a notification when a refresh starts.'),
          value: settings.notifyOnRefreshStart,
          onChanged: (value) => settings.setNotifyOnRefreshStart(value),
        ),
        SwitchListTile(
          title: const Text('Refresh Complete'),
          subtitle: const Text(
            'Receive a notification when a refresh is complete.',
          ),
          value: settings.notifyOnRefreshComplete,
          onChanged: (value) => settings.setNotifyOnRefreshComplete(value),
        ),
        SwitchListTile(
          title: const Text('Errors'),
          subtitle: const Text('Receive a notification when an error occurs.'),
          value: settings.notifyOnErrors,
          onChanged: (value) => settings.setNotifyOnErrors(value),
        ),
      ],
    );
  }

  Widget _buildSystemTraySection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'System Tray'),
        SwitchListTile(
          title: const Text('Enable System Tray'),
          subtitle: const Text(
            'Show an icon in the system tray to manage the application.',
          ),
          value: settings.trayEnabled,
          onChanged: (value) => settings.setTrayEnabled(value),
        ),
        if (settings.trayEnabled)
          SwitchListTile(
            title: const Text('Hide to tray instead of closing'),
            subtitle: const Text(
              'When the window is closed, keep the application running in the tray.',
            ),
            value: settings.hideToTray,
            onChanged: (value) => settings.setHideToTray(value),
          ),
      ],
    );
  }

  Widget _buildPerformanceSection(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildDiagnosticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Diagnostics'),
        ListTile(
          title: const Text('View Activity Log'),
          leading: const Icon(Icons.history),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ActivityLogScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection(
    BuildContext context,
    SettingsProvider settings,
    DevModeProvider devMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Developer'),
        SwitchListTile(
          title: const Text('Developer Mode'),
          subtitle: const Text('Enable advanced features and stats'),
          value: devMode.isDevMode,
          onChanged: (value) => devMode.toggleDevMode(value),
        ),
        SwitchListTile(
          title: const Text('API Logging'),
          subtitle: const Text('Log API requests and responses to console'),
          value: devMode.enableApiLogging,
          onChanged: (value) => devMode.toggleApiLogging(value),
        ),
        SwitchListTile(
          title: const Text('Use Corp Jules Links'),
          subtitle: const Text(
            'Use jules.corp.google.com links instead of jules.google.com for PRs.',
          ),
          value: settings.useCorpJulesUrl,
          onChanged: (value) => settings.setUseCorpJulesUrl(value),
        ),
      ],
    );
  }

  Widget _buildAuthenticationSection(BuildContext context, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Authentication'),
        ListTile(
          title: const Text('Current Session'),
          subtitle: Text(
            auth.tokenType == TokenType.apiKey
                ? 'Manual Access Token'
                : 'Google Access Token',
          ),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
        ),
        ListTile(
          title: const Text('Update Access Token'),
          leading: const Icon(Icons.vpn_key),
          onTap: () => _showApiKeyDialog(context, auth),
        ),
        ListTile(
          title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          leading: const Icon(Icons.logout, color: Colors.red),
          onTap: () => _showSignOutDialog(context, auth),
        ),
      ],
    );
  }

  Widget _buildGitHubSection(
    BuildContext context,
    SettingsProvider settings,
    GithubProvider github,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'GitHub'),
        ListTile(
          title: const Text('Personal Access Token'),
          subtitle: github.hasBadCredentials
              ? Text(
                  'Error: ${github.authError ?? "Bad credentials"}',
                  style: const TextStyle(color: Colors.red),
                )
              : Text(
                  github.apiKey != null && github.apiKey!.length > 4
                      ? '********${github.apiKey!.substring(github.apiKey!.length - 4)}'
                      : (github.apiKey != null ? '********' : 'Not set'),
                ),
          leading: Icon(
            Icons.code,
            color: github.hasBadCredentials ? Colors.red : null,
          ),
          onTap: () => _showGitHubKeyDialog(context, github),
        ),
        if (settings.githubExclusions.isNotEmpty) ...[
          const Divider(),
          _buildSectionHeader(context, 'GitHub Exclusions'),
          _buildGithubExclusionsTable(context, settings),
        ],
      ],
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('Preset: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<SchedulerPreset>(
                  isExpanded: true,
                  hint: const Text('Select configuration template...'),
                  items: SchedulerPreset.presets.map((preset) {
                    return DropdownMenuItem(
                      value: preset,
                      child: Text(preset.name),
                    );
                  }).toList(),
                  onChanged: (preset) {
                    if (preset != null) {
                      _confirmApplyPreset(context, settings, preset);
                    }
                  },
                ),
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
                'Every ${schedule.intervalInMinutes} mins, ${_formatTask(schedule)}\n'
                'Last run: ${_formatLastRun(schedule.lastRun)}',
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

  Future<void> _confirmApplyPreset(
    BuildContext context,
    SettingsProvider settings,
    SchedulerPreset preset,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apply "${preset.name}" Preset?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(preset.description),
            const SizedBox(height: 16),
            const Text(
              'This will replace all current schedules with the selected preset configuration.',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await settings.applySchedulerPreset(preset);
    }
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
    var taskType = schedule?.taskType ?? RefreshTaskType.refresh;
    var sendMessagesMode =
        schedule?.sendMessagesMode ?? SendMessagesMode.sendOne;

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
                  DropdownButtonFormField<RefreshTaskType>(
                    // ignore: deprecated_member_use
                    value: taskType,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          taskType = value;
                        });
                      }
                    },
                    items: RefreshTaskType.values.map((task) {
                      return DropdownMenuItem(
                        value: task,
                        child: Text(task.toString().split('.').last),
                      );
                    }).toList(),
                  ),
                  if (taskType == RefreshTaskType.refresh)
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
                  if (taskType == RefreshTaskType.sendPendingMessages)
                    DropdownButtonFormField<SendMessagesMode>(
                      // ignore: deprecated_member_use
                      value: sendMessagesMode,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            sendMessagesMode = value;
                          });
                        }
                      },
                      items: SendMessagesMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(_formatSendMessagesMode(mode)),
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
                  taskType: taskType,
                  refreshPolicy: taskType == RefreshTaskType.refresh
                      ? refreshPolicy
                      : null,
                  sendMessagesMode:
                      taskType == RefreshTaskType.sendPendingMessages
                          ? sendMessagesMode
                          : null,
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
    TokenType tempType = auth.tokenType;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        bool isTesting = false;
        String? testResult;
        Color? resultColor;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Authentication Credentials'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Type'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TokenType>(
                        value: tempType,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: TokenType.accessToken,
                            child: Text('OAuth Access Token'),
                          ),
                          DropdownMenuItem(
                            value: TokenType.apiKey,
                            child: Text('Jules API Key'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              tempType = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: tempType == TokenType.apiKey
                          ? 'API Key'
                          : 'Access Token',
                      hintText: tempType == TokenType.apiKey
                          ? 'Paste your API Key here'
                          : 'Paste your OAuth2 Access Token here',
                    ),
                    obscureText: true,
                  ),
                  if (isTesting)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: LinearProgressIndicator(),
                    ),
                  if (testResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        testResult!,
                        style: TextStyle(color: resultColor),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final token = controller.text.trim();
                          if (token.isEmpty) return;

                          setState(() {
                            isTesting = true;
                            testResult = null;
                          });

                          try {
                            await auth.validateToken(token, tempType);
                            if (context.mounted) {
                              setState(() {
                                isTesting = false;
                                testResult = 'Success!';
                                resultColor = Colors.green;
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                isTesting = false;
                                testResult = 'Error: $e';
                                resultColor = Colors.red;
                              });
                            }
                          }
                        },
                  child: const Text('Test'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    'token': controller.text,
                    'type': tempType,
                  }),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final newKey = result['token'] as String;
      final type = result['type'] as TokenType;

      if (newKey.isNotEmpty) {
        if (!context.mounted) return;
        await auth.setToken(newKey, type);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credentials updated successfully')),
          );
        }
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

  String _formatListPolicy(ListRefreshPolicy? policy) {
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
      default:
        return '';
    }
  }

  String _formatLastRun(DateTime? lastRun) {
    if (lastRun == null) {
      return 'Never';
    }
    return lastRun.toLocal().toString().substring(0, 16);
  }

  String _formatTask(RefreshSchedule schedule) {
    switch (schedule.taskType) {
      case RefreshTaskType.refresh:
        return _formatListPolicy(schedule.refreshPolicy);
      case RefreshTaskType.sendPendingMessages:
        return 'Send Pending Messages (${_formatSendMessagesMode(schedule.sendMessagesMode)})';
    }
  }

  String _formatSendMessagesMode(SendMessagesMode? mode) {
    switch (mode) {
      case SendMessagesMode.sendOne:
        return 'Send One';
      case SendMessagesMode.sendAllUntilFailure:
        return 'Send All Until Failure';
      default:
        return '';
    }
  }

  Widget _buildThemeModeDropdown(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return ListTile(
      title: const Text('Theme Mode'),
      trailing: DropdownButton<ThemeMode>(
        value: settings.themeMode,
        onChanged: (newValue) {
          if (newValue != null) settings.setThemeMode(newValue);
        },
        items: ThemeMode.values.map((mode) {
          final text = mode.toString().split('.').last;
          return DropdownMenuItem(
            value: mode,
            child: Text(text[0].toUpperCase() + text.substring(1)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeTypeDropdown(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return ListTile(
      title: const Text('Color Theme'),
      trailing: DropdownButton<JulesThemeType>(
        value: settings.themeType,
        onChanged: (newValue) {
          if (newValue != null) settings.setThemeType(newValue);
        },
        items: JulesThemeType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(JulesTheme.getName(type)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFabDropdown(
    BuildContext context, {
    required String title,
    required FabVisibility value,
    required Function(FabVisibility) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<FabVisibility>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        items: FabVisibility.values.map((v) {
          String text = v.toString().split('.').last;
          if (v == FabVisibility.appBar) {
            text = 'App Bar';
          } else if (v == FabVisibility.floating) {
            text = 'Floating';
          } else if (v == FabVisibility.off) {
            text = 'Off';
          } else if (v == FabVisibility.inMenu) {
            text = 'In Menu';
          }
          return DropdownMenuItem(value: v, child: Text(text));
        }).toList(),
      ),
    );
  }

  Widget _buildGithubExclusionsTable(
    BuildContext context,
    SettingsProvider settings,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Value')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Action')),
        ],
        rows: settings.githubExclusions.map((exclusion) {
          return DataRow(
            cells: [
              DataCell(Text(exclusion.type.toString().split('.').last)),
              DataCell(Text(exclusion.value)),
              DataCell(Text(exclusion.reason)),
              DataCell(Text(exclusion.date.toIso8601String().split('T')[0])),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () {
                    settings.removeGithubExclusion(
                      exclusion.value,
                      exclusion.type,
                    );
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeybindingDropdown<T extends Enum>(
    BuildContext context, {
    required String title,
    required T value,
    required List<T> values,
    required Function(T) onChanged,
    required String Function(T) formatter,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) onChanged(newValue);
        },
        items: values.map((v) {
          return DropdownMenuItem(value: v, child: Text(formatter(v)));
        }).toList(),
      ),
    );
  }

  String _formatMessageSubmitAction(MessageSubmitAction action) {
    switch (action) {
      case MessageSubmitAction.addNewLine:
        return 'Adds a new line';
      case MessageSubmitAction.submitsMessage:
        return 'Submits message';
      case MessageSubmitAction.submitsMessageAndGoesBack:
        return 'Submits message and goes back';
      case MessageSubmitAction.submitsMessageMarksReadAndOpensNext:
        return 'Send message, Mark as read, Open next';
      case MessageSubmitAction.doesNothing:
        return 'Does nothing';
    }
  }

  String _formatEscKeyAction(EscKeyAction action) {
    switch (action) {
      case EscKeyAction.savesDraftAndGoesBack:
        return 'Saves draft and goes back';
      case EscKeyAction.goesBack:
        return 'Goes back';
      case EscKeyAction.doesNothing:
        return 'Does nothing';
    }
  }
}
