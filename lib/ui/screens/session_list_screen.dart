import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../services/auth_provider.dart';
import '../../services/session_provider.dart';
import '../../services/source_provider.dart';
import '../../services/cache_service.dart';
import '../../utils/time_helper.dart';
import '../../services/dev_mode_provider.dart';

import '../../models.dart';
import '../widgets/new_session_dialog.dart';
import 'session_detail_screen.dart';
import '../widgets/session_meta_pills.dart';
import '../widgets/advanced_search_bar.dart';
import '../widgets/bulk_action_dialog.dart';
import '../widgets/api_viewer.dart';
import 'package:flutter_jules/ui/widgets/github_queue_pane.dart';
import '../widgets/model_viewer.dart';
import '../widgets/popup_text.dart';
import '../../services/message_queue_provider.dart';
import '../../services/settings_provider.dart';
import '../session_helpers.dart';
import '../widgets/tag_management_dialog.dart';
import '../widgets/note_dialog.dart';

import 'dart:async';
import 'dart:convert';
import '../../services/exceptions.dart';
import '../../services/notification_service.dart';

class SessionListScreen extends StatefulWidget {
  final String? sourceFilter;

  const SessionListScreen({super.key, this.sourceFilter});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class NewSessionIntent extends Intent {
  const NewSessionIntent();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final FocusNode _focusNode = FocusNode();
  // Search & Filter State
  // Search & Filter State
  FilterElement? _filterTree;
  String _searchText = '';
  // Multi-column sorting
  List<SortOption> _activeSorts = [
    const SortOption(SortField.updated, SortDirection.descending),
  ];

  List<CachedItem<Session>> _displayItems = [];

  // Computed suggestions based on available data
  List<FilterToken> _availableSuggestions = [];
  late NotificationService _notificationService;
  StreamSubscription<NotificationResponse>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationService = context.read<NotificationService>();
    _notificationSubscription = _notificationService
        .onNotificationResponseStream
        .listen((response) {
          if (!mounted) return;
          if (response.payload != null) {
            try {
              final session = _displayItems
                  .firstWhere((item) => item.data.name == response.payload)
                  .data;

              if (response.actionId == 'open_pr') {
                if (session.outputs != null &&
                    session.outputs!.any((o) => o.pullRequest != null)) {
                  final pr = session.outputs!
                      .firstWhere((o) => o.pullRequest != null)
                      .pullRequest!;
                  launchUrl(Uri.parse(pr.url));
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(session: session),
                  ),
                );
              }
            } catch (_) {
              // Session not loaded or found
            }
          }
        });

    _focusNode.requestFocus();
    if (widget.sourceFilter != null) {
      // Pre-populate source filter if passed from arguments
      _filterTree = SourceElement(widget.sourceFilter!, widget.sourceFilter!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load last used filter if no explicit filter is set
      if (widget.sourceFilter == null) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.lastFilter != _filterTree) {
          setState(() {
            _filterTree = settings.lastFilter;
          });
        }
      }

      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token != null) {
        // Trigger generic load
        _fetchSessions();
        // Background load sources
        Provider.of<SourceProvider>(
          context,
          listen: false,
        ).fetchSources(auth.client, authToken: auth.token);
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions({bool force = false, bool shallow = true}) async {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await sessionProvider.fetchSessions(
        auth.client,
        force: force,
        shallow: shallow,
        pageSize: settings.sessionPageSize,
        authToken: auth.token,
        onRefreshFallback: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );

      if (mounted) {
        if (sessionProvider.error != null) {
          // Naive offline detection: if error occurs, assume offline?
          // Or just let user see error.
          // Better: If error is not null, suggest going offline or auto-set?
          // Let's auto-set if it looks like a network issue or just generic error for now.
          final queueProvider = Provider.of<MessageQueueProvider>(
            context,
            listen: false,
          );
          // Only auto-switch if we aren't already explicitly one way or another?
          // Actually, if it fails, we are effectively offline.
          if (!queueProvider.isOffline) {
            queueProvider.setOffline(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Connection failed, switching to offline mode"),
              ),
            );
          }
        } else {
          // Success
          final queueProvider = Provider.of<MessageQueueProvider>(
            context,
            listen: false,
          );
          if (queueProvider.queue.isNotEmpty && !queueProvider.isOffline) {}
        }
      }
    } catch (e) {
      // Provider handles error state
    }
  }

  void _openBulkActionDialog() {
    showDialog(
      context: context,
      builder: (context) => BulkActionDialog(
        currentFilterTree: _filterTree,
        currentSorts: _activeSorts,
        availableSuggestions: _availableSuggestions,
        mainSearchText: _searchText,
      ),
    );
  }

  Future<void> _createSession() async {
    // Determine pre-selected source from active filters
    String? preSelectedSource = widget.sourceFilter;
    if (preSelectedSource == null) {
      final activeFilters = FilterElementBuilder.toFilterTokens(_filterTree);
      final activeSource = activeFilters.firstWhere(
        (f) => f.type == FilterType.source && f.mode == FilterMode.include,
        orElse: () => const FilterToken(
          id: '',
          type: FilterType.flag,
          label: '',
          value: '',
        ),
      );
      if (activeSource.id.isNotEmpty) {
        preSelectedSource = activeSource.value;
      }
    }

    final NewSessionResult? result = await showDialog<NewSessionResult>(
      context: context,
      builder: (context) => NewSessionDialog(sourceFilter: preSelectedSource),
    );

    if (result == null) return;
    if (!mounted) return;

    if (result.isDraft) {
      // Handle drafts (loops through all if multiple)
      final queueProvider = Provider.of<MessageQueueProvider>(
        context,
        listen: false,
      );
      for (final session in result.sessions) {
        queueProvider.addCreateSessionRequest(session, isDraft: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.sessions.length > 1 ? "Drafts saved" : "Draft saved",
          ),
        ),
      );
      return;
    }

    final sessionsToCreate = result.sessions;

    Future<void> performCreate(Session sessionToCreate) async {
      try {
        final client = Provider.of<AuthProvider>(context, listen: false).client;
        await client.createSession(sessionToCreate);

        if (!mounted) return;

        // Trigger refresh based on settings
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        switch (settings.refreshOnCreate) {
          case ListRefreshPolicy.none:
            break;
          case ListRefreshPolicy.dirty:
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<SessionProvider>(
              context,
              listen: false,
            ).refreshDirtySessions(client, authToken: auth.token!);
            break;
          case ListRefreshPolicy.watched:
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<SessionProvider>(
              context,
              listen: false,
            ).refreshWatchedSessions(client, authToken: auth.token!);
            break;
          case ListRefreshPolicy.quick:
            _fetchSessions(force: true, shallow: true);
            break;
          case ListRefreshPolicy.full:
            _fetchSessions(force: true, shallow: false);
            break;
        }
      } catch (e) {
        if (!mounted) return;

        bool handled = false;
        if (e is JulesException && e.responseBody != null) {
          try {
            final body = jsonDecode(e.responseBody!);
            if (body is Map && body.containsKey('error')) {
              final error = body['error'];
              if (error is Map) {
                if (error['code'] == 429 ||
                    error['status'] == 'RESOURCE_EXHAUSTED') {
                  // Queue automatically
                  Provider.of<MessageQueueProvider>(
                    context,
                    listen: false,
                  ).addCreateSessionRequest(
                    sessionToCreate,
                    reason: 'resource_exhausted',
                  );
                  // Don't spam snackbars for bulk
                  if (sessionsToCreate.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "API Quota Exhausted. Session creation queued.",
                        ),
                      ),
                    );
                  }
                  handled = true;
                } else if (error['code'] == 503 ||
                    error['status'] == 'UNAVAILABLE') {
                  // Queue automatically
                  Provider.of<MessageQueueProvider>(
                    context,
                    listen: false,
                  ).addCreateSessionRequest(
                    sessionToCreate,
                    reason: 'service_unavailable',
                  );
                  if (sessionsToCreate.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Service Unavailable. Session creation queued.",
                        ),
                      ),
                    );
                  }
                  handled = true;
                }
              }
            }
          } catch (_) {}
        }

        if (!handled) {
          // If bulk, we probably shouldn't show a dialog for each error.
          // Queue it and show snackbar.
          Provider.of<MessageQueueProvider>(
            context,
            listen: false,
          ).addCreateSessionRequest(sessionToCreate, reason: 'creation_failed');
          if (sessionsToCreate.length == 1) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Error Creating Session'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(e.toString()),
                      const SizedBox(height: 16),
                      const Divider(),
                      const Text(
                        "Your Prompt:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(sessionToCreate.prompt),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
        }
      }
    }

    if (sessionsToCreate.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Starting creation of ${sessionsToCreate.length} sessions...',
          ),
        ),
      );
    }

    for (final session in sessionsToCreate) {
      await performCreate(session);
    }

    if (sessionsToCreate.length > 1) {
      // Final feedback
      // We could check if any are queued and report.
      // This check is a bit loose, but good enough for UI feedback
      // Ideally performCreate would return status.
    }
  }

  Future<void> _quickReply(Session session) async {
    final TextEditingController controller = TextEditingController();
    final bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quick Reply to ${session.title ?? "Session"}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (shouldSend == true && controller.text.isNotEmpty) {
      if (!mounted) return;
      try {
        final client = Provider.of<AuthProvider>(context, listen: false).client;
        await client.sendMessage(session.name, controller.text);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message sent')));
          _fetchSessions(
            force: true,
          ); // Refresh so list updates (e.g. timestamp)
        }
      } catch (e) {
        if (!mounted) return;
        bool handled = false;
        if (e is JulesException && e.responseBody != null) {
          try {
            final body = jsonDecode(e.responseBody!);
            if (body is Map && body.containsKey('error')) {
              final error = body['error'];
              if (error is Map &&
                  (error['code'] == 429 ||
                      error['status'] == 'RESOURCE_EXHAUSTED')) {
                // Queue it
                final queueProvider = Provider.of<MessageQueueProvider>(
                  context,
                  listen: false,
                );
                queueProvider.addMessage(
                  session.id,
                  controller.text,
                  reason: 'resource_exhausted',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "API Error: Resource Exhausted. Message queued for later.",
                      ),
                    ),
                  );
                }
                handled = true;
              }
            }
          } catch (_) {
            // Ignore
          }
        }

        if (!handled && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
        }
      }
    }
    controller.dispose();
  }

  Future<void> _refreshSession(Session session) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );

      await sessionProvider.refreshSession(
        auth.client,
        session.name,
        authToken: auth.token,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session refreshed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh session: $e')),
        );
      }
    }
  }

  void _openSessionUrl(Session session) {
    if (session.url != null) {
      launchUrl(Uri.parse(session.url!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available for this session')),
      );
    }
  }

  void _openSourceUrl(String sourceName) {
    // Expected format: sources/github/{owner}/{repo}
    if (sourceName.startsWith("sources/github/")) {
      final parts = sourceName.split('/');
      if (parts.length >= 4) {
        final owner = parts[2];
        final repo = parts[3];
        final url = Uri.parse("https://github.com/$owner/$repo");
        launchUrl(url);
        return;
      }
    }

    // Fallback or generic handling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cannot open URL for source: $sourceName')),
    );
  }

  void _openSessionById() async {
    final controller = TextEditingController();
    final String? sessionId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open Session by ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session ID',
            hintText: 'Enter complete session ID',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (sessionId != null && sessionId.trim().isNotEmpty) {
      if (!mounted) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final client = Provider.of<AuthProvider>(context, listen: false).client;
        final session = await client.getSession(sessionId.trim());

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load session: $e')));
      }
    }
  }

  void _showContextMenu(BuildContext context, {Session? session}) {
    final lastExchange = Provider.of<SessionProvider>(
      context,
      listen: false,
    ).lastExchange;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dev Tools'),
        children: [
          if (lastExchange != null)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ApiViewer(exchange: lastExchange),
                );
              },
              child: const Text('View Source (List API)'),
            ),
          if (session != null)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ModelViewer(
                    data: session.toJson(),
                    title: 'Session Data',
                  ),
                );
              },
              child: const Text('View Session Data'),
            ),
        ],
      ),
    );
  }

  void _updateSuggestions(List<Session> sessions) {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final Set<FilterToken> suggestions = {};

    // Statuses
    for (final status in SessionState.values) {
      if (status == SessionState.STATE_UNSPECIFIED) continue;
      suggestions.add(
        FilterToken(
          id: 'status:${status.name}',
          type: FilterType.status,
          label: status.displayName,
          value: status,
        ),
      );
    }

    // PR Statuses (Common ones - always available to filter by)
    for (final status in ['Open', 'Closed', 'Merged', 'Draft']) {
      suggestions.add(
        FilterToken(
          id: 'prStatus:$status',
          type: FilterType.prStatus,
          label: 'PR: $status',
          value: status,
        ),
      );
    }

    // CI Statuses
    for (final status in ['Success', 'Failure', 'Pending', 'No Checks']) {
      suggestions.add(
        FilterToken(
          id: 'ciStatus:$status',
          type: FilterType.ciStatus,
          label: 'CI: $status',
          value: status,
        ),
      );
    }

    // Sources (from SourceProvider for completeness)
    final allSources = sourceProvider.items.map((i) => i.data);
    for (final source in allSources) {
      if (source.name.startsWith("sources/github/")) {
        suggestions.add(
          FilterToken(
            id: 'source:${source.name}',
            type: FilterType.source,
            label: source.name.replaceFirst('sources/github/', ''),
            value: source.name,
          ),
        );
      } else {
        suggestions.add(
          FilterToken(
            id: 'source:${source.name}',
            type: FilterType.source,
            label: source.name,
            value: source.name,
          ),
        );
      }
    }

    suggestions.add(
      const FilterToken(
        id: 'source:no_source',
        type: FilterType.source,
        label: 'No Source',
        value: 'no_source',
      ),
    );

    // Flags
    suggestions.add(
      const FilterToken(
        id: 'flag:new',
        type: FilterType.flag,
        label: 'New',
        value: 'new',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:updated',
        type: FilterType.flag,
        label: 'Updated',
        value: 'updated',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:unread',
        type: FilterType.flag,
        label: 'Unread',
        value: 'unread',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:pending',
        type: FilterType.flag,
        label: 'Pending',
        value: 'pending',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:watched',
        type: FilterType.flag,
        label: 'Watching',
        value: 'watched',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:hidden',
        type: FilterType.flag,
        label: 'Hidden',
        value: 'hidden',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:has_pr',
        type: FilterType.flag,
        label: 'Has PR',
        value: 'has_pr',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:draft',
        type: FilterType.flag,
        label: 'Has Drafts',
        value: 'draft',
      ),
    );
    suggestions.add(
      const FilterToken(
        id: 'flag:has_notes',
        type: FilterType.flag,
        label: 'Has Notes',
        value: 'has_notes',
      ),
    );

    _availableSuggestions = suggestions.toList();
    // Sort suggestions? Maybe by type then label
    _availableSuggestions.sort((a, b) {
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.label.compareTo(b.label);
    });
  }

  void _markAsRead(Session session) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token != null) {
      Provider.of<SessionProvider>(
        context,
        listen: false,
      ).markAsRead(session.id, auth.token!);
    }
  }

  Future<void> _refreshGitStatus(Session session) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Authentication required")));
      return;
    }

    try {
      await Provider.of<SessionProvider>(
        context,
        listen: false,
      ).refreshGitStatus(session.id, auth.token!);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Git status refreshed")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to refresh Git status: $e")),
        );
      }
    }
  }

  void _viewRawData(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final sessions = sessionProvider.items.map((i) => i.data.toJson()).toList();

    showDialog(
      context: context,
      builder: (context) => ModelViewer(
        data: {'sessions': sessions, 'count': sessions.length},
        title: 'Raw Session Data (Reconstructed)',
      ),
    );
  }

  int _compareSessions(CachedItem<Session> a, CachedItem<Session> b) {
    for (final sort in _activeSorts) {
      int cmp = 0;
      switch (sort.field) {
        case SortField.updated:
          cmp = _getEffectiveTime(a).compareTo(_getEffectiveTime(b));
          break;
        case SortField.created:
          final tA = a.data.createTime != null
              ? DateTime.parse(a.data.createTime!)
              : DateTime(0);
          final tB = b.data.createTime != null
              ? DateTime.parse(b.data.createTime!)
              : DateTime(0);
          cmp = tA.compareTo(tB);
          break;
        case SortField.name:
          cmp = (a.data.title ?? a.data.name).compareTo(
            b.data.title ?? b.data.name,
          );
          break;
        case SortField.source:
          cmp = (a.data.sourceContext?.source ?? '').compareTo(
            b.data.sourceContext?.source ?? '',
          );
          break;
        case SortField.status:
          final indexA = a.data.state?.index ?? -1;
          final indexB = b.data.state?.index ?? -1;
          cmp = indexA.compareTo(indexB);
          break;
      }

      if (cmp != 0) {
        return sort.direction == SortDirection.ascending ? cmp : -cmp;
      }
    }
    return 0; // Equal
  }

  void _addFilterToken(FilterToken token) {
    final element = _tokenToElement(token);
    if (element == null) return;

    setState(() {
      _filterTree = FilterElementBuilder.addFilter(_filterTree, element);
    });
  }

  FilterElement? _tokenToElement(FilterToken token) {
    FilterElement? element;
    switch (token.type) {
      case FilterType.status:
        element = StatusElement(token.label, token.value.toString());
        break;
      case FilterType.source:
        if (token.value.toString() == 'no_source') {
          element = NoSourceElement();
        } else {
          element = SourceElement(token.label, token.value.toString());
        }
        break;
      case FilterType.prStatus:
        element = PrStatusElement(token.label, token.value.toString());
        break;
      case FilterType.ciStatus:
        element = CiStatusElement(token.label, token.value.toString());
        break;
      case FilterType.text:
        element = LabelElement(token.label, token.value.toString());
        break;
      case FilterType.flag:
        if (token.value.toString() == 'has_pr' || token.id == 'flag:has_pr') {
          element = HasPrElement();
        } else {
          element = LabelElement(token.label, token.value.toString());
        }
        break;
      case FilterType.tag:
        element = TagElement(token.label, token.value.toString());
        break;
      default:
        return null;
    }
    if (token.mode == FilterMode.exclude) {
      return NotElement(element);
    }
    return element;
  }

  void _addSortOption(SortOption option) {
    // Check if field exists
    final index = _activeSorts.indexWhere((s) => s.field == option.field);
    setState(() {
      if (index != -1) {
        _activeSorts[index] = option; // Update direction
      } else {
        _activeSorts.add(option);
      }
    });
  }

  Widget _buildPill(
    BuildContext context, {
    required Session session,
    required CacheMetadata metadata,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required FilterToken filterToken,
    SortField? sortField,
  }) {
    void showPillMenu(Offset globalPosition) {
      final queueProvider = Provider.of<MessageQueueProvider>(
        context,
        listen: false,
      );
      final hasDrafts = queueProvider.getDrafts(session.id).isNotEmpty;
      final hasPr = session.outputs?.any((o) => o.pullRequest != null) ?? false;

      final List<Map<String, dynamic>> allFlags = [
        {
          'id': 'flag:new',
          'label': 'New',
          'value': 'new',
          'active': metadata.isNew,
        },
        {
          'id': 'flag:updated',
          'label': 'Updated',
          'value': 'updated',
          'active': metadata.isUpdated,
        },
        {
          'id': 'flag:unread',
          'label': 'Unread',
          'value': 'unread',
          'active': metadata.isUnread,
        },
        {
          'id': 'flag:watched',
          'label': 'Watching',
          'value': 'watched',
          'active': metadata.isWatched,
        },
        {
          'id': 'flag:draft',
          'label': 'Has Drafts',
          'value': 'draft',
          'active': hasDrafts,
        },
        {
          'id': 'flag:has_pr',
          'label': 'Has PR',
          'value': 'has_pr',
          'active': hasPr,
        },
      ];

      // If this is a status pill, add other statuses
      final isStatusPill = filterToken.type == FilterType.status;
      final List<Map<String, dynamic>> statusOptions = [];
      if (isStatusPill) {
        for (final status in SessionState.values) {
          if (status == SessionState.STATE_UNSPECIFIED) continue;

          final statusLabel = status.displayName;
          // Determine if this is the current session's status
          final isCurrent = session.state == status;

          statusOptions.add({
            'id': 'status:${status.name}',
            'label': statusLabel,
            'value': status,
            'active': isCurrent,
            'type': 'status',
          });
        }
      }

      final activeFlags = allFlags.where((f) => f['active'] == true).toList();
      final otherFlags = allFlags.where((f) => f['active'] == false).toList();
      final customLabels = metadata.labels;

      final List<PopupMenuEntry> menuItems = [];

      void addTokenOptions(FilterToken token, {bool isActive = false}) {
        menuItems.add(
          PopupMenuItem(
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.add_circle_outline,
                  size: 16,
                  color: isActive ? Colors.green : null,
                ),
                const SizedBox(width: 8),
                Text("Filter ${token.label}"),
              ],
            ),
            onTap: () =>
                _addFilterToken(token.copyWith(mode: FilterMode.include)),
          ),
        );
        menuItems.add(
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(
                  Icons.remove_circle_outline,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text("Exclude ${token.label}"),
              ],
            ),
            onTap: () =>
                _addFilterToken(token.copyWith(mode: FilterMode.exclude)),
          ),
        );
      }

      if (statusOptions.isNotEmpty) {
        menuItems.add(
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'ALL STATUSES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.blueGrey,
              ),
            ),
          ),
        );
        for (final option in statusOptions) {
          addTokenOptions(
            FilterToken(
              id: option['id'],
              type: FilterType.status,
              label: option['label'],
              value: option['value'],
            ),
            isActive: option['active'] == true,
          );
        }
        menuItems.add(const PopupMenuDivider());
      }

      if (activeFlags.isNotEmpty || customLabels.isNotEmpty) {
        menuItems.add(
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'ACTIVE LABELS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.blue,
              ),
            ),
          ),
        );
        for (final flag in activeFlags) {
          addTokenOptions(
            FilterToken(
              id: flag['id'],
              type: FilterType.flag,
              label: flag['label'],
              value: flag['value'],
            ),
            isActive: true,
          );
        }
        for (final l in customLabels) {
          addTokenOptions(
            FilterToken(
              id: 'text:$l',
              type: FilterType.text,
              label: l,
              value: l,
            ),
            isActive: true,
          );
        }
      }

      if (otherFlags.isNotEmpty) {
        if (menuItems.isNotEmpty) menuItems.add(const PopupMenuDivider());
        menuItems.add(
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'ALTERNATIVES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
        );
        for (final flag in otherFlags) {
          addTokenOptions(
            FilterToken(
              id: flag['id'],
              type: FilterType.flag,
              label: flag['label'],
              value: flag['value'],
            ),
          );
        }
      }

      if (sortField != null) {
        if (menuItems.isNotEmpty) menuItems.add(const PopupMenuDivider());
        menuItems.add(
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.arrow_upward, size: 16),
                SizedBox(width: 8),
                Text("Sort Ascending"),
              ],
            ),
            onTap: () =>
                _addSortOption(SortOption(sortField, SortDirection.ascending)),
          ),
        );
        menuItems.add(
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.arrow_downward, size: 16),
                SizedBox(width: 8),
                Text("Sort Descending"),
              ],
            ),
            onTap: () =>
                _addSortOption(SortOption(sortField, SortDirection.descending)),
          ),
        );
      }

      final RenderBox overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      );

      showMenu(context: context, position: position, items: menuItems);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showPillMenu(details.globalPosition),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  DateTime _getEffectiveTime(CachedItem<Session> item) {
    if (item.data.updateTime != null) {
      return DateTime.parse(item.data.updateTime!);
    }
    if (item.data.createTime != null) {
      return DateTime.parse(item.data.createTime!);
    }
    return item.metadata.lastRetrieved;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final cachedItems = sessionProvider.items;
        final isLoading = sessionProvider.isLoading;
        final error = sessionProvider.error;
        final lastFetchTime = sessionProvider.lastFetchTime;
        final queueProvider = Provider.of<MessageQueueProvider>(context);

        // Inject draft sessions
        // Inject draft and pending sessions
        final draftSessions = queueProvider.queue
            .where(
              (m) =>
                  m.type == QueuedMessageType.sessionCreation ||
                  m.sessionId == 'new_session',
            ) // Include legacy or pending
            .map((m) {
              Map<String, dynamic> json;
              if (m.metadata != null) {
                json = Map<String, dynamic>.from(m.metadata!);
              } else {
                // Fallback for items without metadata
                json = {
                  'id': 'temp',
                  'name': 'temp',
                  'prompt': m.content,
                  'sourceContext': {'source': 'unknown'},
                };
              }

              // Override ID to avoid collision
              json['id'] = 'DRAFT_CREATION_${m.id}';

              // Ensure prompt is set as title
              if (json['title'] == null || json['title'].toString().isEmpty) {
                json['title'] =
                    (json['prompt'] as String?) ?? 'New Session (Draft)';
              }

              final isDraft = m.isDraft;
              final isOffline =
                  queueProvider.isOffline; // Uses provider from context

              // Inject Flags based on queue state
              // User Definition: "Pending" is for all new sessions (draft, error, sending).
              // Status 'QUEUED' maps to "Pending" in UI usually.

              json['state'] =
                  'QUEUED'; // Always QUEUED to match "Pending" filter

              String statusReason;
              if (m.processingErrors.isNotEmpty) {
                final lastError = m.processingErrors.last;
                if (lastError.contains('429') ||
                    lastError.toLowerCase().contains('quota')) {
                  statusReason = 'Quota limit reached';
                } else if (lastError.contains('500') ||
                    lastError.contains('502') ||
                    lastError.contains('503')) {
                  statusReason = 'Server error';
                } else {
                  statusReason = 'Failed: $lastError';
                }
              } else if (isDraft) {
                statusReason = m.queueReason ?? 'Saved as draft';
              } else if (isOffline) {
                // It's pending sending, but we are offline
                statusReason = 'Pending (Offline)';
              } else {
                // Pending sending, online
                statusReason = 'Sending to server...';
              }

              json['currentAction'] = statusReason;

              final session = Session.fromJson(json);

              return CachedItem(
                session,
                CacheMetadata(
                  firstSeen: m.createdAt,
                  lastRetrieved: m.createdAt,
                  labels: isDraft ? ['DRAFT_CREATION'] : ['PENDING_CREATION'],
                  hasPendingUpdates: !isDraft,
                ),
              );
            })
            .toList();

        final allItems = [...draftSessions, ...cachedItems];

        // Populate suggestions once data is loaded (and if not done yet or data changed substantially)
        // Ideally we do this only when list changes, but 'build' is fine for now as it's cheap
        _updateSuggestions(allItems.map((i) => i.data).toList());

        _displayItems = allItems.where((item) {
          final session = item.data;
          final metadata = item.metadata;

          // Separate text search from filter tree for now, or integrate it?
          // The current design keeps _searchText separate.
          // Apply text search first (optimization)
          if (_searchText.isNotEmpty) {
            final query = _searchText.toLowerCase();
            final matches =
                (session.title?.toLowerCase().contains(query) ?? false) ||
                (session.name.toLowerCase().contains(query)) ||
                (session.id.toLowerCase().contains(query)) ||
                (session.state.toString().toLowerCase().contains(query));
            if (!matches) return false;
          }

          // Evaluate the filter tree using new FilterState logic
          final initialState = metadata.isHidden
              ? FilterState.implicitOut
              : FilterState.implicitIn;

          if (_filterTree == null) {
            return initialState.isIn;
          }

          final treeResult = _filterTree!.evaluate(
            FilterContext(
              session: session,
              metadata: metadata,
              queueProvider: queueProvider,
            ),
          );

          final finalState = FilterState.combineAnd(initialState, treeResult);
          return finalState.isIn;
        }).toList();

        _displayItems.sort(_compareSessions);

        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
                const NewSessionIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              NewSessionIntent: CallbackAction<NewSessionIntent>(
                onInvoke: (NewSessionIntent intent) => _createSession(),
              ),
            },
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Sessions'),
                  bottom: isLoading
                      ? const PreferredSize(
                          preferredSize: Size.fromHeight(4.0),
                          child: LinearProgressIndicator(),
                        )
                      : null,
                  actions: [
                    Consumer<MessageQueueProvider>(
                      builder: (context, queueProvider, _) {
                        if (queueProvider.isOffline) {
                          if (queueProvider.isConnecting) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                          return IconButton(
                            icon: const Icon(Icons.wifi_off),
                            tooltip: "Go Online",
                            onPressed: () async {
                              final auth = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final online = await queueProvider.goOnline(
                                auth.client,
                              );
                              if (online && mounted) {
                                _fetchSessions(force: true);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Still offline"),
                                  ),
                                );
                              }
                            },
                          );
                        }
                        return IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () =>
                              _fetchSessions(force: true, shallow: true),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'full_refresh') {
                          _fetchSessions(force: true, shallow: false);
                        } else if (value == 'bulk_actions') {
                          _openBulkActionDialog();
                        } else if (value == 'settings') {
                          Navigator.pushNamed(context, '/settings');
                        } else if (value == 'sources') {
                          Navigator.pushNamed(context, '/sources_raw');
                        } else if (value == 'raw_data') {
                          _viewRawData(context);
                        } else if (value == 'go_offline') {
                          final queueProvider =
                              Provider.of<MessageQueueProvider>(
                                context,
                                listen: false,
                              );
                          if (!queueProvider.isOffline) {
                            queueProvider.setOffline(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Switched to Offline Mode"),
                              ),
                            );
                          }
                        } else if (value == 'refresh_dirty') {
                          final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final sessionProvider = Provider.of<SessionProvider>(
                            context,
                            listen: false,
                          );
                          sessionProvider.refreshDirtySessions(
                            auth.client,
                            authToken: auth.token!,
                          );
                        } else if (value == 'open_by_id') {
                          _openSessionById();
                        } else if (value == 'github_status') {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => const GithubQueuePane(),
                          );
                        }
                      },
                      itemBuilder: (context) {
                        final isOffline = Provider.of<MessageQueueProvider>(
                          context,
                          listen: false,
                        ).isOffline;
                        return [
                          const PopupMenuItem(
                            value: 'full_refresh',
                            child: Row(
                              children: [
                                Icon(Icons.refresh),
                                SizedBox(width: 8),
                                Text('Full Refresh'),
                              ],
                            ),
                          ),
                          if (_displayItems.isNotEmpty)
                            const PopupMenuItem(
                              value: 'bulk_actions',
                              child: Row(
                                children: [
                                  Icon(Icons.checklist),
                                  SizedBox(width: 8),
                                  Text('Bulk Actions...'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'open_by_id',
                            child: Row(
                              children: [
                                Icon(Icons.input),
                                SizedBox(width: 8),
                                Text('Open by Session ID'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'github_status',
                            child: Row(
                              children: [
                                Icon(Icons.dashboard_customize),
                                SizedBox(width: 8),
                                Text('GitHub Status & Queue'),
                              ],
                            ),
                          ),
                          if (!isOffline)
                            const PopupMenuItem(
                              value: 'go_offline',
                              child: Row(
                                children: [
                                  Icon(Icons.wifi_off),
                                  SizedBox(width: 8),
                                  Text('Go Offline'),
                                ],
                              ),
                            ),
                          if (!isOffline)
                            const PopupMenuItem(
                              value: 'refresh_dirty',
                              child: Row(
                                children: [
                                  Icon(Icons.sync_problem),
                                  SizedBox(width: 8),
                                  Text('Refresh Dirty Sessions'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'raw_data',
                            child: Row(
                              children: [
                                Icon(Icons.data_object),
                                SizedBox(width: 8),
                                Text('View Raw Data'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'settings',
                            child: Row(
                              children: [
                                Icon(Icons.settings),
                                SizedBox(width: 8),
                                Text('Settings'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sources',
                            child: Row(
                              children: [
                                Icon(Icons.source),
                                SizedBox(width: 8),
                                Text('Manage Sources'),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                body: (cachedItems.isEmpty && isLoading)
                    ? const Center(child: Text("Loading sessions..."))
                    : (cachedItems.isEmpty && error != null)
                    ? Center(child: Text('Error: $error'))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: AdvancedSearchBar(
                              filterTree: _filterTree,
                              onFilterTreeChanged: (tree) {
                                setState(() {
                                  _filterTree = tree;
                                });
                                // Also save to settings
                                final settings = Provider.of<SettingsProvider>(
                                  context,
                                  listen: false,
                                );
                                settings.setLastFilter(tree);
                              },
                              searchText: _searchText,
                              onSearchChanged: (text) {
                                setState(() {
                                  _searchText = text;
                                });
                              },
                              availableSuggestions: _availableSuggestions,
                              activeSorts: _activeSorts,
                              onSortsChanged: (sorts) {
                                setState(() {
                                  _activeSorts = sorts;
                                });
                              },
                            ),
                          ),
                          if (lastFetchTime != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Last refreshed: ${DateFormat.Hms().format(lastFetchTime)} (${timeAgo(lastFetchTime)})',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color:
                                            DateTime.now()
                                                    .difference(lastFetchTime)
                                                    .inMinutes >
                                                15
                                            ? Colors.orange
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                      ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () =>
                                  _fetchSessions(force: true, shallow: true),
                              child: ListView.builder(
                                itemCount: _displayItems.length,
                                itemBuilder: (context, index) {
                                  final cachedItem = _displayItems[index];
                                  final session = cachedItem.data;
                                  final metadata = cachedItem.metadata;
                                  final isDevMode =
                                      Provider.of<DevModeProvider>(
                                        context,
                                      ).isDevMode;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        if (session.id.startsWith(
                                          'DRAFT_CREATION_',
                                        )) {
                                          final realId = session.id.substring(
                                            15,
                                          ); // Length of DRAFT_CREATION_
                                          if (!queueProvider.queue.any(
                                            (m) => m.id == realId,
                                          )) {
                                            return;
                                          }

                                          // Reuse Logic inline
                                          // We can't easily call _openDraft here without duplication or refactor.
                                          // Let's implement inline for now.
                                          final result =
                                              await showDialog<
                                                NewSessionResult
                                              >(
                                                context: context,
                                                builder: (context) =>
                                                    NewSessionDialog(
                                                      initialSession: session,
                                                    ),
                                              );

                                          if (result == null) return;
                                          if (!context.mounted) return;

                                          if (result.isDelete) {
                                            queueProvider.deleteMessage(realId);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text("Draft deleted"),
                                              ),
                                            );
                                          } else if (result.isDraft) {
                                            // Draft Update is always single
                                            queueProvider
                                                .updateCreateSessionRequest(
                                                  realId,
                                                  result.session,
                                                  isDraft: true,
                                                );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text("Draft updated"),
                                              ),
                                            );
                                          } else {
                                            // Send Now: Delete draft, add new request (non-draft)
                                            queueProvider.deleteMessage(realId);
                                            // Add new request
                                            queueProvider
                                                .addCreateSessionRequest(
                                                  result.session,
                                                  isDraft: false,
                                                );
                                            // Also could call _createSession direct logic if online
                                            // But queuing is safer/consistent.
                                            // But if we want immediate feedback like "Creating...", we normally do that.
                                            // But here we are in list.
                                            // Let's try to send immediately if possible?
                                            // Actually, just queuing as non-draft will trigger auto-send if online?
                                            // MessageQueueProvider 'sendQueue' needs to be triggered.
                                            // Or assume queue provider handles it?
                                            // queueProvider.sendQueue() is usually manual or on connection.
                                            // Let's trigger it.
                                            final auth =
                                                Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            queueProvider.sendQueue(
                                              auth.client,
                                              onSessionCreated: (newSession) {
                                                // Immediately add to provider
                                                Provider.of<SessionProvider>(
                                                  context,
                                                  listen: false,
                                                ).updateSession(
                                                  newSession,
                                                  authToken: auth.token,
                                                );
                                              },
                                            );
                                          }
                                          return;
                                        }

                                        _markAsRead(session);
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SessionDetailScreen(
                                              session: session,
                                            ),
                                          ),
                                        );

                                        // On Return
                                        if (!context.mounted) return;
                                        final settings =
                                            Provider.of<SettingsProvider>(
                                              context,
                                              listen: false,
                                            );
                                        switch (settings.refreshOnReturn) {
                                          case ListRefreshPolicy.none:
                                            break;
                                          case ListRefreshPolicy.dirty:
                                            final auth =
                                                Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            Provider.of<SessionProvider>(
                                              context,
                                              listen: false,
                                            ).refreshDirtySessions(
                                              auth.client,
                                              authToken: auth.token!,
                                            );
                                            break;
                                          case ListRefreshPolicy.watched:
                                            final auth =
                                                Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            Provider.of<SessionProvider>(
                                              context,
                                              listen: false,
                                            ).refreshWatchedSessions(
                                              auth.client,
                                              authToken: auth.token!,
                                            );
                                            break;
                                          case ListRefreshPolicy.quick:
                                            _fetchSessions(
                                              force: true,
                                              shallow: true,
                                            );
                                            break;
                                          case ListRefreshPolicy.full:
                                            _fetchSessions(
                                              force: true,
                                              shallow: false,
                                            );
                                            break;
                                        }
                                      },
                                      onLongPress: () {
                                        _showTileMenu(
                                          context,
                                          session,
                                          metadata,
                                          isDevMode,
                                        );
                                      },
                                      onSecondaryTapUp: (details) {
                                        _showTileMenu(
                                          context,
                                          session,
                                          metadata,
                                          isDevMode,
                                          position: details.globalPosition,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      if (Provider.of<
                                                            MessageQueueProvider
                                                          >(context)
                                                          .getDrafts(session.id)
                                                          .isNotEmpty)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: 'DRAFT',
                                                          backgroundColor:
                                                              Colors.orange,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken:
                                                              const FilterToken(
                                                                id: 'flag:draft',
                                                                type: FilterType
                                                                    .flag,
                                                                label:
                                                                    'Has Drafts',
                                                                value: 'draft',
                                                              ),
                                                        ),
                                                      if (metadata.isNew)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: 'NEW',
                                                          backgroundColor:
                                                              Colors.green,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken:
                                                              const FilterToken(
                                                                id: 'flag:new',
                                                                type: FilterType
                                                                    .flag,
                                                                label: 'New',
                                                                value: 'new',
                                                              ),
                                                          sortField:
                                                              SortField.created,
                                                        ),
                                                      if (metadata.isUpdated &&
                                                          !metadata.isNew)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: 'UPDATED',
                                                          backgroundColor:
                                                              Colors.amber,
                                                          textColor:
                                                              Colors.black,
                                                          filterToken:
                                                              const FilterToken(
                                                                id: 'flag:updated',
                                                                type: FilterType
                                                                    .flag,
                                                                label:
                                                                    'Updated',
                                                                value:
                                                                    'updated',
                                                              ),
                                                          sortField:
                                                              SortField.updated,
                                                        ),
                                                      if (metadata.isUnread &&
                                                          !metadata.isNew &&
                                                          !metadata.isUpdated)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: 'UNREAD',
                                                          backgroundColor:
                                                              Colors.blueAccent,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken:
                                                              const FilterToken(
                                                                id: 'flag:unread',
                                                                type: FilterType
                                                                    .flag,
                                                                label: 'Unread',
                                                                value: 'unread',
                                                              ),
                                                        ),
                                                      if (metadata.isWatched)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: 'WATCHING',
                                                          backgroundColor:
                                                              Colors.deepPurple,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken:
                                                              const FilterToken(
                                                                id: 'flag:watched',
                                                                type: FilterType
                                                                    .flag,
                                                                label:
                                                                    'Watching',
                                                                value:
                                                                    'watched',
                                                              ),
                                                        ),
                                                      // PR Status - only for final states (Closed/Merged)
                                                      if (session.prStatus !=
                                                              null &&
                                                          (session.prStatus ==
                                                                  'Closed' ||
                                                              session.prStatus ==
                                                                  'Merged'))
                                                        _buildPill(
                                                          context,
                                                          metadata: metadata,
                                                          session: session,
                                                          label:
                                                              '${session.prStatus}',
                                                          backgroundColor:
                                                              session.prStatus ==
                                                                  'Merged'
                                                              ? Colors.green
                                                              : Colors.red,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken: FilterToken(
                                                            id: 'prStatus:${session.prStatus}',
                                                            type: FilterType
                                                                .prStatus,
                                                            label:
                                                                'PR: ${session.prStatus}',
                                                            value: session
                                                                .prStatus!,
                                                          ),
                                                        ),

                                                      // Render custom labels
                                                      for (final label
                                                          in metadata.labels)
                                                        _buildPill(
                                                          context,
                                                          session: session,
                                                          metadata: metadata,
                                                          label: label
                                                              .toUpperCase(),
                                                          backgroundColor:
                                                              Colors
                                                                  .grey
                                                                  .shade700,
                                                          textColor:
                                                              Colors.white,
                                                          filterToken:
                                                              FilterToken(
                                                                id: 'text:$label',
                                                                type: FilterType
                                                                    .text,
                                                                label: label,
                                                                value: label,
                                                              ),
                                                        ),

                                                      Expanded(
                                                        child: LayoutBuilder(
                                                          builder: (context, constraints) {
                                                            // Simple responsive logic for max lines
                                                            int maxLines = 1;
                                                            if (constraints
                                                                    .maxWidth >
                                                                800) {
                                                              maxLines = 3;
                                                            } else if (constraints
                                                                    .maxWidth >
                                                                400) {
                                                              maxLines = 2;
                                                            }

                                                            return PopupText(
                                                              (session.title ??
                                                                      session
                                                                          .prompt)
                                                                  .replaceAll(
                                                                    '\n',
                                                                    ' ',
                                                                  ),
                                                              maxLines:
                                                                  maxLines,
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    (metadata
                                                                        .isUnread)
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                                fontSize: 16,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Trailing Menu Button
                                                InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  onTapDown: (details) {
                                                    _showTileMenu(
                                                      context,
                                                      session,
                                                      metadata,
                                                      isDevMode,
                                                      position: details
                                                          .globalPosition,
                                                    );
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(
                                                      8.0,
                                                    ),
                                                    child: Icon(
                                                      Icons.more_vert,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                                if (session.outputs != null &&
                                                    session.outputs!.any(
                                                      (o) =>
                                                          o.pullRequest != null,
                                                    ))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4.0,
                                                        ),
                                                    child: GestureDetector(
                                                      onSecondaryTapUp: (details) {
                                                        final RenderBox
                                                        overlay =
                                                            Overlay.of(context)
                                                                    .context
                                                                    .findRenderObject()
                                                                as RenderBox;
                                                        final RelativeRect
                                                        position = RelativeRect.fromRect(
                                                          Rect.fromPoints(
                                                            details
                                                                .globalPosition,
                                                            details
                                                                .globalPosition,
                                                          ),
                                                          Offset.zero &
                                                              overlay.size,
                                                        );
                                                        showMenu(
                                                          context: context,
                                                          position: position,
                                                          items: <PopupMenuEntry>[
                                                            PopupMenuItem(
                                                              child: const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .filter_alt,
                                                                    size: 16,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Filter 'Has PR'",
                                                                  ),
                                                                ],
                                                              ),
                                                              onTap: () {
                                                                _addFilterToken(
                                                                  const FilterToken(
                                                                    id: 'flag:has_pr',
                                                                    type: FilterType
                                                                        .flag,
                                                                    label:
                                                                        'Has Pull Request',
                                                                    value:
                                                                        'has_pr',
                                                                    mode: FilterMode
                                                                        .include,
                                                                  ),
                                                                );
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).hideCurrentSnackBar();
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      "Added filter: Has Pull Request",
                                                                    ),
                                                                    duration:
                                                                        Duration(
                                                                          seconds:
                                                                              1,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            PopupMenuItem(
                                                              child: const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .filter_alt_off,
                                                                    size: 16,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Exclude 'Has PR'",
                                                                  ),
                                                                ],
                                                              ),
                                                              onTap: () {
                                                                _addFilterToken(
                                                                  const FilterToken(
                                                                    id: 'flag:has_pr',
                                                                    type: FilterType
                                                                        .flag,
                                                                    label:
                                                                        'Has Pull Request',
                                                                    value:
                                                                        'has_pr',
                                                                    mode: FilterMode
                                                                        .exclude,
                                                                  ),
                                                                );
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).hideCurrentSnackBar();
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      "Added filter: Exclude Has Pull Request",
                                                                    ),
                                                                    duration:
                                                                        Duration(
                                                                          seconds:
                                                                              1,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            const PopupMenuDivider(),
                                                            PopupMenuItem(
                                                              child: const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons.copy,
                                                                    size: 16,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Copy PR URL",
                                                                  ),
                                                                ],
                                                              ),
                                                              onTap: () {
                                                                final pr = session
                                                                    .outputs!
                                                                    .firstWhere(
                                                                      (o) =>
                                                                          o.pullRequest !=
                                                                          null,
                                                                    )
                                                                    .pullRequest!;
                                                                Clipboard.setData(
                                                                  ClipboardData(
                                                                    text:
                                                                        pr.url,
                                                                  ),
                                                                );
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      "PR URL copied to clipboard",
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.merge_type,
                                                          color: Colors.purple,
                                                        ),
                                                        tooltip:
                                                            'Open Pull Request',
                                                        onPressed: () {
                                                          final pr = session
                                                              .outputs!
                                                              .firstWhere(
                                                                (o) =>
                                                                    o.pullRequest !=
                                                                    null,
                                                              )
                                                              .pullRequest!;
                                                          launchUrl(
                                                            Uri.parse(pr.url),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            SessionMetaPills(
                                              session: session,
                                              compact: true,
                                              onAddFilter: (token) {
                                                _addFilterToken(token);
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).hideCurrentSnackBar();
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Added filter: ${token.label}",
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 1,
                                                    ),
                                                  ),
                                                );
                                              },
                                              onAddSort: _addSortOption,
                                            ),
                                            // Progress bar if running
                                            if (session.state ==
                                                    SessionState.IN_PROGRESS &&
                                                session.totalSteps != null &&
                                                session.totalSteps! > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: LinearProgressIndicator(
                                                  value:
                                                      session.currentStep! /
                                                      session.totalSteps!,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                floatingActionButton: FloatingActionButton(
                  onPressed: _createSession,
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTileMenu(
    BuildContext context,
    Session session,
    CacheMetadata metadata,
    bool isDevMode, {
    Offset? position,
  }) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect finalPosition = position != null
        ? RelativeRect.fromRect(
            Rect.fromPoints(position, position),
            Offset.zero & overlay.size,
          )
        : RelativeRect.fromLTRB(
            overlay.size.width / 2,
            overlay.size.height / 2,
            overlay.size.width / 2,
            overlay.size.height / 2,
          ); // Center fallback

    showMenu(
      context: context,
      position: finalPosition,
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          child: Row(
            children: [
              Icon(metadata.isHidden ? Icons.visibility : Icons.visibility_off),
              const SizedBox(width: 8),
              Text(metadata.isHidden ? 'Unhide' : 'Hide'),
            ],
          ),
          onTap: () {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<SessionProvider>(
              context,
              listen: false,
            ).toggleHidden(session.id, auth.token!);
          },
        ),
        if (session.url != null) ...[
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.open_in_browser),
                SizedBox(width: 8),
                Text('Open in Browser'),
              ],
            ),
            onTap: () => _openSessionUrl(session),
          ),
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.link),
                SizedBox(width: 8),
                Text('Copy Session URL'),
              ],
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: session.url!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Session URL copied to clipboard"),
                ),
              );
            },
          ),
        ],
        if (metadata.isUnread || metadata.isNew || metadata.isUpdated)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.mark_email_read),
                SizedBox(width: 8),
                Text('Mark as Read'),
              ],
            ),
            onTap: () => _markAsRead(session),
          ),
        if (session.outputs != null &&
            session.outputs!.any((o) => o.pullRequest != null)) ...[
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.merge_type),
                SizedBox(width: 8),
                Text('Open PR & Mark Read'),
              ],
            ),
            onTap: () {
              final pr = session.outputs!
                  .firstWhere((o) => o.pullRequest != null)
                  .pullRequest!;
              launchUrl(Uri.parse(pr.url)).then((success) {
                if (success) {
                  _markAsRead(session);
                }
              });
            },
          ),
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.copy),
                SizedBox(width: 8),
                Text('Copy PR URL'),
              ],
            ),
            onTap: () {
              final pr = session.outputs!
                  .firstWhere((o) => o.pullRequest != null)
                  .pullRequest!;
              Clipboard.setData(ClipboardData(text: pr.url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("PR URL copied to clipboard")),
              );
            },
          ),
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 8),
                Text('Refresh Git Status'),
              ],
            ),
            onTap: () => _refreshGitStatus(session),
          ),
        ],
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.reply),
              SizedBox(width: 8),
              Text('Quick Reply'),
            ],
          ),
          onTap: () => _quickReply(session),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.note_add),
              SizedBox(width: 8),
              Text('Edit Note'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (mounted) _editNote(session);
            });
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.add_circle_outline),
              SizedBox(width: 8),
              Text('Resubmit as new session'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                resubmitSession(context, session, hideOriginal: false);
              }
            });
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.visibility_off_outlined),
              SizedBox(width: 8),
              Text('Resubmit as new session and hide'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                resubmitSession(context, session, hideOriginal: true);
              }
            });
          },
        ),
        const PopupMenuDivider(),
        if (!session.id.startsWith('DRAFT_CREATION_'))
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.refresh),
                SizedBox(width: 8),
                Text('Refresh Session'),
              ],
            ),
            onTap: () {
              Future.delayed(Duration.zero, () {
                if (context.mounted) _refreshSession(session);
              });
            },
          ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.description),
              SizedBox(width: 8),
              Text('View Prompt'),
            ],
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Session Prompt"),
                content: SingleChildScrollView(
                  child: SelectableText(session.prompt),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            );
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.data_object),
              SizedBox(width: 8),
              Text('View Session Source'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => ModelViewer(
                    data: session.toJson(),
                    title: 'Raw Session Source',
                  ),
                );
              }
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(
                metadata.isWatched
                    ? Icons.notifications_off
                    : Icons.notifications_active,
              ),
              const SizedBox(width: 8),
              Text(metadata.isWatched ? 'Stop Watching' : 'Watch Session'),
            ],
          ),
          onTap: () {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<SessionProvider>(
              context,
              listen: false,
            ).toggleWatch(session.id, auth.token!);
          },
        ),
        if (!metadata.isUnread && !metadata.isNew && !metadata.isUpdated)
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.mark_email_unread),
                SizedBox(width: 8),
                Text('Mark as Unread'),
              ],
            ),
            onTap: () {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              Provider.of<SessionProvider>(
                context,
                listen: false,
              ).markAsUnread(session.id, auth.token!);
            },
          ),
        const PopupMenuItem(
          value: 'source',
          child: Row(
            children: [
              Icon(Icons.source),
              SizedBox(width: 8),
              Text('View Source Repo'),
            ],
          ),
        ),
        if (isDevMode) ...[
          PopupMenuItem(
            child: const Row(
              children: [
                Icon(Icons.developer_mode),
                SizedBox(width: 8),
                Text('Dev Tools'),
              ],
            ),
            onTap: () {
              // Wait for menu to close?
              Future.delayed(Duration.zero, () {
                if (context.mounted) {
                  _showContextMenu(context, session: session);
                }
              });
            },
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.label, color: Colors.grey),
              SizedBox(width: 8),
              Text('Manage Tags'),
            ],
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (context) => TagManagementDialog(session: session),
                );
              }
            });
          },
        ),
      ],
    ).then((value) {
      if (value == 'source' && session.sourceContext?.source != null) {
        _openSourceUrl(session.sourceContext!.source);
      }
    });
  }

  Future<void> _editNote(Session session) async {
    final newNote = await showDialog<Note>(
      context: context,
      builder: (context) => NoteDialog(note: session.note),
    );

    if (newNote != null) {
      if (!mounted) return;
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      sessionProvider.updateSession(
        session.copyWith(note: newNote),
        authToken: authProvider.token,
      );
    }
  }
}
