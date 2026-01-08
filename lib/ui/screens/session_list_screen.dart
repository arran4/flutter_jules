import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_provider.dart';
import '../../services/session_provider.dart';
import '../../services/source_provider.dart';
import '../../services/cache_service.dart';
import '../../utils/time_helper.dart';
import '../../services/dev_mode_provider.dart';
import '../../models/cache_metadata.dart';
import '../../models.dart';
import '../widgets/new_session_dialog.dart';
import 'session_detail_screen.dart';
import '../widgets/session_meta_pills.dart';
import '../widgets/advanced_search_bar.dart';
import '../widgets/api_viewer.dart';
import '../widgets/model_viewer.dart';
import '../../services/message_queue_provider.dart';
import '../../services/settings_provider.dart';
import 'offline_queue_screen.dart';
import 'dart:convert';
import '../../services/exceptions.dart';

class SessionListScreen extends StatefulWidget {
  final String? sourceFilter;

  const SessionListScreen({super.key, this.sourceFilter});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  // Search & Filter State
  // Search & Filter State
  List<FilterToken> _activeFilters = [];
  String _searchText = '';
  // Multi-column sorting
  List<SortOption> _activeSorts = [
    const SortOption(SortField.updated, SortDirection.descending)
  ];

  List<CachedItem<Session>> _displayItems = [];

  // Computed suggestions based on available data
  List<FilterToken> _availableSuggestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.sourceFilter != null) {
      // Pre-populate source filter if passed from arguments
      _activeFilters.add(FilterToken(
        id: 'source:${widget.sourceFilter}',
        type: FilterType.source,
        label: widget.sourceFilter!,
        value: widget.sourceFilter!,
      ));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token != null) {
        // Trigger generic load
        _fetchSessions();
        // Background load sources
        Provider.of<SourceProvider>(context, listen: false)
            .fetchSources(auth.client, authToken: auth.token);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchSessions({bool force = false, bool shallow = true}) async {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await sessionProvider.fetchSessions(auth.client,
          force: force,
          shallow: shallow,
          pageSize: settings.sessionPageSize,
          authToken: auth.token, onRefreshFallback: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      });

      if (mounted) {
        if (sessionProvider.error != null) {
          // Naive offline detection: if error occurs, assume offline?
          // Or just let user see error.
          // Better: If error is not null, suggest going offline or auto-set?
          // Let's auto-set if it looks like a network issue or just generic error for now.
          final queueProvider =
              Provider.of<MessageQueueProvider>(context, listen: false);
          // Only auto-switch if we aren't already explicitly one way or another?
          // Actually, if it fails, we are effectively offline.
          if (!queueProvider.isOffline) {
            queueProvider.setOffline(true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Connection failed, switching to offline mode")));
          }
        } else {
          // Success
          final queueProvider =
              Provider.of<MessageQueueProvider>(context, listen: false);
          if (queueProvider.queue.isNotEmpty && !queueProvider.isOffline) {
            _promptSendQueue(context, queueProvider);
          }
        }
      }
    } catch (e) {
      // Provider handles error state
    }
  }

  void _promptSendQueue(BuildContext context, MessageQueueProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("You have ${provider.queue.length} pending messages."),
      action: SnackBarAction(
        label: "SEND ALL",
        onPressed: () async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await provider.sendQueue(auth.client, onError: (id, e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Error: $e")));
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("Queue processed")));
          }
        },
      ),
    ));
  }

  Future<void> _createSession() async {
    // Determine pre-selected source from active filters
    String? preSelectedSource = widget.sourceFilter;
    if (preSelectedSource == null) {
      final activeSource = _activeFilters.firstWhere(
          (f) => f.type == FilterType.source && f.mode == FilterMode.include,
          orElse: () => const FilterToken(
              id: '', type: FilterType.flag, label: '', value: ''));
      if (activeSource.id.isNotEmpty) {
        preSelectedSource = activeSource.value;
      }
    }

    final Session? sessionToCreate = await showDialog<Session>(
      context: context,
      builder: (context) => NewSessionDialog(sourceFilter: preSelectedSource),
    );

    if (sessionToCreate == null) return;
    if (!mounted) return;

    Future<void> performCreate() async {
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
            Provider.of<SessionProvider>(context, listen: false)
                .refreshDirtySessions(client, authToken: auth.token!);
            break;
          case ListRefreshPolicy.watched:
            final auth = Provider.of<AuthProvider>(context, listen: false);
            Provider.of<SessionProvider>(context, listen: false)
                .refreshWatchedSessions(client, authToken: auth.token!);
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
              if (error is Map &&
                  (error['code'] == 429 ||
                      error['status'] == 'RESOURCE_EXHAUSTED')) {
                // Queue automatically
                Provider.of<MessageQueueProvider>(context, listen: false)
                    .addCreateSessionRequest(sessionToCreate);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text("API Quota Exhausted. Session creation queued.")));
                handled = true;
              }
            }
          } catch (_) {}
        }

        if (!handled) {
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
                    const Text("Your Prompt:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4)),
                        child: SelectableText(sessionToCreate.prompt)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Provider.of<MessageQueueProvider>(context, listen: false)
                        .addCreateSessionRequest(sessionToCreate);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Session creation queued.")));
                  },
                  child: const Text('Queue'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    performCreate(); // Retry
                  },
                  child: const Text('Try Again'),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
            ),
          );
        }
      }
    }

    await performCreate();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent')),
          );
          _fetchSessions(
              force: true); // Refresh so list updates (e.g. timestamp)
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
                final queueProvider =
                    Provider.of<MessageQueueProvider>(context, listen: false);
                queueProvider.addMessage(session.id, controller.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          "API Error: Resource Exhausted. Message queued for later.")));
                }
                handled = true;
              }
            }
          } catch (_) {
            // Ignore
          }
        }

        if (!handled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending message: $e')),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _refreshSession(Session session) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);

      await sessionProvider.refreshSession(auth.client, session.name,
          authToken: auth.token);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session refreshed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh session: $e')),
        );
      }
    }
  }

  Future<void> _refreshVisibleSessions() async {
    final count = _displayItems.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Refreshing $count visible sessions...')),
    );

    for (final item in _displayItems) {
      await _refreshSession(item.data);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visible sessions refreshed')),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load session: $e')),
        );
      }
    }
  }

  void _showContextMenu(BuildContext context, {Session? session}) {
    final lastExchange =
        Provider.of<SessionProvider>(context, listen: false).lastExchange;

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
    final Set<FilterToken> suggestions = {};

    // Statuses
    for (final status in SessionState.values) {
      if (status == SessionState.STATE_UNSPECIFIED) continue;
      suggestions.add(FilterToken(
        id: 'status:${status.name}',
        type: FilterType.status,
        label: status.displayName,
        value: status,
      ));
    }

    // Sources (from sessions)
    final sources = sessions.map((s) => s.sourceContext.source).toSet();
    for (final source in sources) {
      if (source.startsWith("sources/github/")) {
        suggestions.add(FilterToken(
          id: 'source:$source',
          type: FilterType.source,
          label: source.replaceFirst('sources/github/', ''),
          value: source,
        ));
      } else {
        suggestions.add(FilterToken(
          id: 'source:$source',
          type: FilterType.source,
          label: source,
          value: source,
        ));
      }
    }

    // Flags
    suggestions.add(const FilterToken(
        id: 'flag:new', type: FilterType.flag, label: 'New', value: 'new'));
    suggestions.add(const FilterToken(
        id: 'flag:updated',
        type: FilterType.flag,
        label: 'Updated',
        value: 'updated'));
    suggestions.add(const FilterToken(
        id: 'flag:unread',
        type: FilterType.flag,
        label: 'Unread',
        value: 'unread'));
    suggestions.add(const FilterToken(
        id: 'flag:watched',
        type: FilterType.flag,
        label: 'Watching',
        value: 'watched'));
    suggestions.add(const FilterToken(
        id: 'flag:hidden',
        type: FilterType.flag,
        label: 'Hidden',
        value: 'hidden'));

    _availableSuggestions = suggestions.toList();
    // Sort suggestions? Maybe by type then label
    _availableSuggestions.sort((a, b) {
      if (a.type != b.type) return a.type.index.compareTo(b.type.index);
      return a.label.compareTo(b.label);
    });
  }

  void _showFilterMenu() {
    // Group suggestions by type for better UI
    final statusSuggestions = _availableSuggestions
        .where((s) => s.type == FilterType.status)
        .toList();
    final flagSuggestions =
        _availableSuggestions.where((s) => s.type == FilterType.flag).toList();
    final sourceSuggestions = _availableSuggestions
        .where((s) => s.type == FilterType.source)
        .toList();
    final otherSuggestions = _availableSuggestions
        .where((s) => s.type == FilterType.text)
        .toList(); // If any

    // Ordered list of sections
    final sections = [
      {'title': 'Status', 'items': statusSuggestions},
      {'title': 'Flags', 'items': flagSuggestions},
      // Others if needed
      if (otherSuggestions.isNotEmpty)
        {'title': 'Tags', 'items': otherSuggestions},
      {'title': 'Sources', 'items': sourceSuggestions}, // Sources Last
    ];

    showDialog(
        context: context,
        builder: (context) {
          // Use StatefulBuilder to allow UI updates within the dialog when state changes
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("All Filters"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, // Limit height
                child: ListView(
                  shrinkWrap: true,
                  children: sections.map((section) {
                    final title = section['title'] as String;
                    final items = section['items'] as List<FilterToken>;
                    if (items.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ),
                        ...items.map((suggestion) {
                          // Check current state in _activeFilters
                          final activeFilter = _activeFilters.firstWhere(
                              (f) =>
                                  f.id == suggestion.id &&
                                  f.mode == FilterMode.include,
                              orElse: () => const FilterToken(
                                  id: '',
                                  type: FilterType.flag,
                                  label: '',
                                  value: ''));
                          final isIncluded = activeFilter.id.isNotEmpty;

                          final activeExclude = _activeFilters.firstWhere(
                              (f) =>
                                  f.id == suggestion.id &&
                                  f.mode == FilterMode.exclude,
                              orElse: () => const FilterToken(
                                  id: '',
                                  type: FilterType.flag,
                                  label: '',
                                  value: ''));
                          final isExcluded = activeExclude.id.isNotEmpty;

                          return ListTile(
                            leading: _getIconForType(suggestion.type),
                            title: Text(suggestion.label),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Include Button
                                IconButton(
                                  icon: Icon(Icons.add_circle,
                                      color: isIncluded
                                          ? Colors.green
                                          : Colors.grey.shade300),
                                  tooltip: "Include",
                                  onPressed: () {
                                    setState(() {
                                      // Update parent state
                                      _activeFilters.removeWhere(
                                          (f) => f.id == suggestion.id);
                                      if (!isIncluded) {
                                        _activeFilters.add(FilterToken(
                                            id: suggestion.id,
                                            type: suggestion.type,
                                            label: suggestion.label,
                                            value: suggestion.value,
                                            mode: FilterMode.include));
                                      }
                                    });
                                    setDialogState(
                                        () {}); // Refreshes the dialog UI
                                  },
                                ),
                                // Exclude Button
                                IconButton(
                                  icon: Icon(Icons.remove_circle,
                                      color: isExcluded
                                          ? Colors.red
                                          : Colors.grey.shade300),
                                  tooltip: "Exclude",
                                  onPressed: () {
                                    setState(() {
                                      _activeFilters.removeWhere(
                                          (f) => f.id == suggestion.id);
                                      if (!isExcluded) {
                                        _activeFilters.add(FilterToken(
                                            id: suggestion.id,
                                            type: suggestion.type,
                                            label: suggestion.label,
                                            value: suggestion.value,
                                            mode: FilterMode.exclude));
                                      }
                                    });
                                    setDialogState(
                                        () {}); // Refreshes the dialog UI
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(),
                      ],
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Done"))
              ],
            );
          });
        });
  }

  Icon _getIconForType(FilterType type) {
    switch (type) {
      case FilterType.status:
        return const Icon(Icons.info_outline, size: 16);
      case FilterType.source:
        return const Icon(Icons.source, size: 16);
      case FilterType.flag:
        return const Icon(Icons.flag, size: 16);
      case FilterType.text:
        return const Icon(Icons.text_fields, size: 16);
    }
  }

  void _markAsRead(Session session) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.token != null) {
      Provider.of<SessionProvider>(context, listen: false)
          .markAsRead(session.id, auth.token!);
    }
  }

  void _viewRawData(BuildContext context) {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
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
          cmp = (a.data.title ?? a.data.name)
              .compareTo(b.data.title ?? b.data.name);
          break;
        case SortField.source:
          cmp = a.data.sourceContext.source
              .compareTo(b.data.sourceContext.source);
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
    // Check if exists
    if (!_activeFilters.any((t) => t.id == token.id)) {
      setState(() {
        _activeFilters.add(token);
      });
    } else {
      // If it exists but mode is different, update it?
      // Or if user explicitly clicked "Filter: New" but "NOT New" is active, maybe flip it?
      // Converting existing to the requested one
      setState(() {
        _activeFilters.removeWhere((t) => t.id == token.id);
        _activeFilters.add(token);
      });
    }
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
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required FilterToken filterToken,
    SortField? sortField,
  }) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(details.globalPosition, details.globalPosition),
          Offset.zero & overlay.size,
        );

        showMenu(context: context, position: position, items: <PopupMenuEntry>[
          PopupMenuItem(
            child: Row(children: [
              const Icon(Icons.filter_alt, size: 16),
              const SizedBox(width: 8),
              Text("Filter '${filterToken.label}'")
            ]),
            onTap: () => _addFilterToken(FilterToken(
                id: filterToken.id,
                type: filterToken.type,
                label: filterToken.label,
                value: filterToken.value,
                mode: FilterMode.include)),
          ),
          PopupMenuItem(
            child: Row(children: [
              const Icon(Icons.filter_alt_off, size: 16),
              const SizedBox(width: 8),
              Text("Exclude '${filterToken.label}'")
            ]),
            onTap: () => _addFilterToken(FilterToken(
                id: filterToken.id,
                type: filterToken.type,
                label: filterToken.label,
                value: filterToken.value,
                mode: FilterMode.exclude)),
          ),
          if (sortField != null) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.arrow_upward, size: 16),
                SizedBox(width: 8),
                Text("Sort Ascending")
              ]),
              onTap: () => _addSortOption(
                  SortOption(sortField, SortDirection.ascending)),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.arrow_downward, size: 16),
                SizedBox(width: 8),
                Text("Sort Descending")
              ]),
              onTap: () => _addSortOption(
                  SortOption(sortField, SortDirection.descending)),
            ),
          ]
        ]);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
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

        // Populate suggestions once data is loaded (and if not done yet or data changed substantially)
        // Ideally we do this only when list changes, but 'build' is fine for now as it's cheap
        _updateSuggestions(cachedItems.map((i) => i.data).toList());

        _displayItems = cachedItems.where((item) {
          final session = item.data;
          final metadata = item.metadata;

          // Default hidden check:
          // If the session is hidden, it should generally NOT be shown...
          // UNLESS the user has explicitly requested to see hidden items via a filter.
          final hasHiddenFilter = _activeFilters.any(
              (f) => f.id == 'flag:hidden' && f.mode == FilterMode.include);
          if (metadata.isHidden && !hasHiddenFilter) {
            return false;
          }

          // Text Search
          if (_searchText.isNotEmpty) {
            final query = _searchText.toLowerCase();
            final matches =
                (session.title?.toLowerCase().contains(query) ?? false) ||
                    (session.name.toLowerCase().contains(query)) ||
                    (session.id.toLowerCase().contains(query)) ||
                    (session.state.toString().toLowerCase().contains(query));
            if (!matches) return false;
          }

          // Filter Tokens Logic
          // Group by Type
          final statusFilters =
              _activeFilters.where((f) => f.type == FilterType.status).toList();
          final sourceFilters =
              _activeFilters.where((f) => f.type == FilterType.source).toList();
          final flagFilters =
              _activeFilters.where((f) => f.type == FilterType.flag).toList();

          // 1. Status: OR logic for Include, AND logic for Exclude
          // e.g. (Active OR Running) AND NOT Failed
          if (statusFilters.isNotEmpty) {
            final includes =
                statusFilters.where((f) => f.mode == FilterMode.include);
            final excludes =
                statusFilters.where((f) => f.mode == FilterMode.exclude);

            if (includes.isNotEmpty) {
              final matchesAny = includes.any((f) => session.state == f.value);
              if (!matchesAny) return false;
            }

            if (excludes.isNotEmpty) {
              final matchesAny = excludes.any((f) => session.state == f.value);
              if (matchesAny) return false;
            }
          }

          // 2. Source: OR logic for Include, AND logic for Exclude
          if (sourceFilters.isNotEmpty) {
            final includes =
                sourceFilters.where((f) => f.mode == FilterMode.include);
            final excludes =
                sourceFilters.where((f) => f.mode == FilterMode.exclude);

            if (includes.isNotEmpty) {
              final matchesAny =
                  includes.any((f) => session.sourceContext.source == f.value);
              if (!matchesAny) return false;
            }

            if (excludes.isNotEmpty) {
              final matchesAny =
                  excludes.any((f) => session.sourceContext.source == f.value);
              if (matchesAny) return false;
            }
          }

          // 3. Flags: AND logic (typically flags are distinct properties)
          // But if I select "New" and "Updated", do I want items that are BOTH? Or either?
          // Usually "Is New" OR "Is Updated". Let's use OR for Includes.
          if (flagFilters.isNotEmpty) {
            final includes =
                flagFilters.where((f) => f.mode == FilterMode.include);
            final excludes =
                flagFilters.where((f) => f.mode == FilterMode.exclude);

            if (includes.isNotEmpty) {
              bool matchesAny = false;
              for (final f in includes) {
                if (f.value == 'new' && metadata.isNew) matchesAny = true;
                if (f.value == 'updated' &&
                    metadata.isUpdated &&
                    !metadata.isNew) {
                  matchesAny = true;
                }
                if (f.value == 'unread' && metadata.isUnread) matchesAny = true;
                if (f.value == 'has_pr' &&
                    (session.outputs?.any((o) => o.pullRequest != null) ??
                        false)) {
                  matchesAny = true;
                }
                if (f.value == 'watched' && metadata.isWatched) {
                  matchesAny = true;
                }
                if (f.value == 'hidden' && metadata.isHidden) {
                  matchesAny = true;
                }
              }
              if (!matchesAny) return false;
            }

            if (excludes.isNotEmpty) {
              bool matchesAny = false;
              for (final f in excludes) {
                if (f.value == 'new' && metadata.isNew) matchesAny = true;
                if (f.value == 'updated' &&
                    metadata.isUpdated &&
                    !metadata.isNew) {
                  matchesAny = true;
                }
                if (f.value == 'unread' && metadata.isUnread) matchesAny = true;
                if (f.value == 'has_pr' &&
                    (session.outputs?.any((o) => o.pullRequest != null) ??
                        false)) {
                  matchesAny = true;
                }
                if (f.value == 'watched' && metadata.isWatched) {
                  matchesAny = true;
                }
                if (f.value == 'hidden' && metadata.isHidden) {
                  matchesAny = true;
                }
              }
              if (matchesAny) return false;
            }
          }

          // 4. Text Filters (Labels/Tag matching)
          // Treat FilterType.text as broad text matching, including Labels
          final textFilters =
              _activeFilters.where((f) => f.type == FilterType.text).toList();
          if (textFilters.isNotEmpty) {
            // Includes
            final includes =
                textFilters.where((f) => f.mode == FilterMode.include);
            if (includes.isNotEmpty) {
              final matchesAny = includes.any((f) {
                final val = f.value.toString().toLowerCase();
                // Check labels
                if (metadata.labels.any((l) => l.toLowerCase() == val)) {
                  return true;
                }
                // Check title/name
                if (session.title?.toLowerCase().contains(val) ?? false) {
                  return true;
                }
                if (session.name.toLowerCase().contains(val)) return true;
                return false;
              });
              if (!matchesAny) return false;
            }

            // Excludes
            final excludes =
                textFilters.where((f) => f.mode == FilterMode.exclude);
            if (excludes.isNotEmpty) {
              final matchesAny = excludes.any((f) {
                final val = f.value.toString().toLowerCase();
                if (metadata.labels.any((l) => l.toLowerCase() == val)) {
                  return true;
                }
                if (session.title?.toLowerCase().contains(val) ?? false) {
                  return true;
                }
                if (session.name.toLowerCase().contains(val)) return true;
                return false;
              });
              if (matchesAny) return false;
            }
          }

          return true;
        }).toList();

        // Sorting
        // Sorting
        _displayItems.sort(_compareSessions);

        return Scaffold(
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
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        final online =
                            await queueProvider.goOnline(auth.client);
                        if (online && mounted) {
                          _fetchSessions(force: true);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Still offline")));
                        }
                      },
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () => _fetchSessions(force: true, shallow: true),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'full_refresh') {
                    _fetchSessions(force: true, shallow: false);
                  } else if (value == 'refresh_visible') {
                    _refreshVisibleSessions();
                  } else if (value == 'settings') {
                    Navigator.pushNamed(context, '/settings');
                  } else if (value == 'sources') {
                    Navigator.pushNamed(context, '/sources_raw');
                  } else if (value == 'raw_data') {
                    _viewRawData(context);
                  } else if (value == 'queue') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OfflineQueueScreen()));
                  } else if (value == 'go_offline') {
                    final queueProvider = Provider.of<MessageQueueProvider>(
                        context,
                        listen: false);
                    if (!queueProvider.isOffline) {
                      queueProvider.setOffline(true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Switched to Offline Mode")));
                    }
                  } else if (value == 'refresh_dirty') {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    final sessionProvider =
                        Provider.of<SessionProvider>(context, listen: false);
                    sessionProvider.refreshDirtySessions(auth.client,
                        authToken: auth.token!);
                  } else if (value == 'open_by_id') {
                    _openSessionById();
                  }
                },
                itemBuilder: (context) {
                  final isOffline =
                      Provider.of<MessageQueueProvider>(context, listen: false)
                          .isOffline;
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
                        value: 'refresh_visible',
                        child: Row(
                          children: [
                            Icon(Icons.sync),
                            SizedBox(width: 8),
                            Text('Refresh Visible Sessions'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'queue',
                      child: Row(
                        children: [
                          Icon(Icons.queue),
                          SizedBox(width: 8),
                          Text('Offline Message Queue'),
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
                            activeFilters: _activeFilters,
                            onFiltersChanged: (filters) {
                              setState(() {
                                _activeFilters = filters;
                              });
                            },
                            onSearchChanged: (text) {
                              setState(() {
                                _searchText = text;
                              });
                            },
                            availableSuggestions: _availableSuggestions,
                            onOpenFilterMenu: _showFilterMenu,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Last refreshed: ${DateFormat.Hms().format(lastFetchTime)} (${timeAgo(lastFetchTime)})',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DateTime.now()
                                                  .difference(lastFetchTime)
                                                  .inMinutes >
                                              15
                                          ? Colors.orange
                                          : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
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
                                    Provider.of<DevModeProvider>(context)
                                        .isDevMode;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: InkWell(
                                    onTap: () async {
                                      _markAsRead(session);
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  SessionDetailScreen(
                                                      session: session)));

                                      // On Return
                                      if (!context.mounted) return;
                                      final settings =
                                          Provider.of<SettingsProvider>(context,
                                              listen: false);
                                      switch (settings.refreshOnReturn) {
                                        case ListRefreshPolicy.none:
                                          break;
                                        case ListRefreshPolicy.dirty:
                                          final auth =
                                              Provider.of<AuthProvider>(context,
                                                  listen: false);
                                          Provider.of<SessionProvider>(context,
                                                  listen: false)
                                              .refreshDirtySessions(auth.client,
                                                  authToken: auth.token!);
                                          break;
                                        case ListRefreshPolicy.watched:
                                          final auth =
                                              Provider.of<AuthProvider>(context,
                                                  listen: false);
                                          Provider.of<SessionProvider>(context,
                                                  listen: false)
                                              .refreshWatchedSessions(
                                                  auth.client,
                                                  authToken: auth.token!);
                                          break;
                                        case ListRefreshPolicy.quick:
                                          _fetchSessions(
                                              force: true, shallow: true);
                                          break;
                                        case ListRefreshPolicy.full:
                                          _fetchSessions(
                                              force: true, shallow: false);
                                          break;
                                      }
                                    },
                                    onLongPress: () {
                                      _showTileMenu(context, session, metadata,
                                          isDevMode);
                                    },
                                    onSecondaryTapUp: (details) {
                                      _showTileMenu(
                                          context, session, metadata, isDevMode,
                                          position: details.globalPosition);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                                child: Row(
                                              children: [
                                                if (metadata.isNew)
                                                  _buildPill(context,
                                                      label: 'NEW',
                                                      backgroundColor:
                                                          Colors.green,
                                                      textColor: Colors.white,
                                                      filterToken:
                                                          const FilterToken(
                                                              id: 'flag:new',
                                                              type: FilterType
                                                                  .flag,
                                                              label: 'New',
                                                              value: 'new'),
                                                      sortField:
                                                          SortField.created),
                                                if (metadata.isUpdated &&
                                                    !metadata.isNew)
                                                  _buildPill(context,
                                                      label: 'UPDATED',
                                                      backgroundColor: Colors
                                                          .amber,
                                                      textColor: Colors.black,
                                                      filterToken:
                                                          const FilterToken(
                                                              id:
                                                                  'flag:updated',
                                                              type: FilterType
                                                                  .flag,
                                                              label: 'Updated',
                                                              value: 'updated'),
                                                      sortField:
                                                          SortField.updated),
                                                if (metadata.isUnread &&
                                                    !metadata.isNew &&
                                                    !metadata.isUpdated)
                                                  _buildPill(
                                                    context,
                                                    label: 'UNREAD',
                                                    backgroundColor:
                                                        Colors.blueAccent,
                                                    textColor: Colors.white,
                                                    filterToken:
                                                        const FilterToken(
                                                            id: 'flag:unread',
                                                            type:
                                                                FilterType.flag,
                                                            label: 'Unread',
                                                            value: 'unread'),
                                                  ),
                                                if (metadata.isWatched)
                                                  _buildPill(
                                                    context,
                                                    label: 'WATCHING',
                                                    backgroundColor:
                                                        Colors.deepPurple,
                                                    textColor: Colors.white,
                                                    filterToken:
                                                        const FilterToken(
                                                            id: 'flag:watched',
                                                            type:
                                                                FilterType.flag,
                                                            label: 'Watching',
                                                            value: 'watched'),
                                                  ),

                                                // Render custom labels
                                                for (final label
                                                    in metadata.labels)
                                                  _buildPill(
                                                    context,
                                                    label: label.toUpperCase(),
                                                    backgroundColor:
                                                        Colors.grey.shade700,
                                                    textColor: Colors.white,
                                                    filterToken: FilterToken(
                                                        id: 'text:$label',
                                                        type: FilterType.text,
                                                        label: label,
                                                        value: label),
                                                  ),

                                                Expanded(
                                                  child: Text(
                                                      session.title ??
                                                          session.prompt,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontWeight: (metadata
                                                                  .isUnread)
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                          fontSize: 16)),
                                                ),
                                              ],
                                            )),
                                            // Trailing Menu Button
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTapDown: (details) {
                                                _showTileMenu(context, session,
                                                    metadata, isDevMode,
                                                    position:
                                                        details.globalPosition);
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Icon(Icons.more_vert,
                                                    size: 20),
                                              ),
                                            ),
                                            if (session.outputs != null &&
                                                session.outputs!.any((o) =>
                                                    o.pullRequest != null))
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 4.0),
                                                child: GestureDetector(
                                                  onSecondaryTapUp: (details) {
                                                    final RenderBox overlay =
                                                        Overlay.of(context)
                                                                .context
                                                                .findRenderObject()
                                                            as RenderBox;
                                                    final RelativeRect
                                                        position =
                                                        RelativeRect.fromRect(
                                                      Rect.fromPoints(
                                                          details
                                                              .globalPosition,
                                                          details
                                                              .globalPosition),
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
                                                                      size: 16),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Text(
                                                                      "Filter 'Has PR'")
                                                                ]),
                                                            onTap: () {
                                                              _addFilterToken(const FilterToken(
                                                                  id:
                                                                      'flag:has_pr',
                                                                  type:
                                                                      FilterType
                                                                          .flag,
                                                                  label:
                                                                      'Has Pull Request',
                                                                  value:
                                                                      'has_pr',
                                                                  mode: FilterMode
                                                                      .include));
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .hideCurrentSnackBar();
                                                              ScaffoldMessenger
                                                                      .of(
                                                                          context)
                                                                  .showSnackBar(
                                                                      const SnackBar(
                                                                content: Text(
                                                                    "Added filter: Has Pull Request"),
                                                                duration:
                                                                    Duration(
                                                                        seconds:
                                                                            1),
                                                              ));
                                                            },
                                                          ),
                                                          PopupMenuItem(
                                                            child: const Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .filter_alt_off,
                                                                      size: 16),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Text(
                                                                      "Exclude 'Has PR'")
                                                                ]),
                                                            onTap: () {
                                                              _addFilterToken(const FilterToken(
                                                                  id:
                                                                      'flag:has_pr',
                                                                  type:
                                                                      FilterType
                                                                          .flag,
                                                                  label:
                                                                      'Has Pull Request',
                                                                  value:
                                                                      'has_pr',
                                                                  mode: FilterMode
                                                                      .exclude));
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .hideCurrentSnackBar();
                                                              ScaffoldMessenger
                                                                      .of(
                                                                          context)
                                                                  .showSnackBar(
                                                                      const SnackBar(
                                                                content: Text(
                                                                    "Added filter: Exclude Has Pull Request"),
                                                                duration:
                                                                    Duration(
                                                                        seconds:
                                                                            1),
                                                              ));
                                                            },
                                                          ),
                                                          const PopupMenuDivider(),
                                                          PopupMenuItem(
                                                            child: const Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .copy,
                                                                      size: 16),
                                                                  SizedBox(
                                                                      width: 8),
                                                                  Text(
                                                                      "Copy PR URL")
                                                                ]),
                                                            onTap: () {
                                                              final pr = session
                                                                  .outputs!
                                                                  .firstWhere((o) =>
                                                                      o.pullRequest !=
                                                                      null)
                                                                  .pullRequest!;
                                                              Clipboard.setData(
                                                                  ClipboardData(
                                                                      text: pr
                                                                          .url));
                                                              ScaffoldMessenger
                                                                      .of(
                                                                          context)
                                                                  .showSnackBar(
                                                                      const SnackBar(
                                                                content: Text(
                                                                    "PR URL copied to clipboard"),
                                                              ));
                                                            },
                                                          ),
                                                        ]);
                                                  },
                                                  child: IconButton(
                                                    icon: const Icon(
                                                        Icons.merge_type,
                                                        color: Colors.purple),
                                                    tooltip:
                                                        'Open Pull Request',
                                                    onPressed: () {
                                                      final pr = session
                                                          .outputs!
                                                          .firstWhere((o) =>
                                                              o.pullRequest !=
                                                              null)
                                                          .pullRequest!;
                                                      launchUrl(
                                                          Uri.parse(pr.url));
                                                    },
                                                  ),
                                                ),
                                              ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert),
                                              tooltip: 'Actions',
                                              onSelected: (value) async {
                                                final auth =
                                                    Provider.of<AuthProvider>(
                                                        context,
                                                        listen: false);
                                                if (value == 'pr') {
                                                  final pr = session.outputs!
                                                      .firstWhere((o) =>
                                                          o.pullRequest != null)
                                                      .pullRequest!;
                                                  launchUrl(Uri.parse(pr.url));
                                                } else if (value == 'pr_read') {
                                                  final pr = session.outputs!
                                                      .firstWhere((o) =>
                                                          o.pullRequest != null)
                                                      .pullRequest!;
                                                  await sessionProvider
                                                      .markPrAsOpened(
                                                          session.id,
                                                          auth.token!);
                                                  launchUrl(Uri.parse(pr.url));
                                                } else if (value == 'browser') {
                                                  _openSessionUrl(session);
                                                } else if (value == 'copy_pr_url') {
                                                  final prUrl = session.outputs
                                                      ?.firstWhere((o) => o.pullRequest != null, orElse: () => Output())
                                                      .pullRequest?.url;
                                                  if (prUrl != null) {
                                                    Clipboard.setData(ClipboardData(text: prUrl));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('PR URL copied to clipboard')),
                                                    );
                                                  }
                                                } else if (value == 'copy_jules_url') {
                                                  if (session.url != null) {
                                                    Clipboard.setData(ClipboardData(text: session.url!));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Jules URL copied to clipboard')),
                                                    );
                                                  }
                                                }else if (value == 'reply') {
                                                  _quickReply(session);
                                                } else if (value ==
                                                    'view_prompt') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          "Session Prompt"),
                                                      content:
                                                          SingleChildScrollView(
                                                        child: SelectableText(
                                                            session.prompt),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          child: const Text(
                                                              "Close"),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'refresh') {
                                                  _refreshSession(session);
                                                } else if (value == 'source') {
                                                  _openSourceUrl(session
                                                      .sourceContext.source);
                                                } else if (value == 'raw') {
                                                  _showContextMenu(context,
                                                      session: session);
                                                } else if (value ==
                                                    'mark_read') {
                                                  await sessionProvider
                                                      .markAsRead(session.id,
                                                          auth.token!);
                                                } else if (value ==
                                                    'mark_unread') {
                                                  await sessionProvider
                                                      .markAsUnread(session.id,
                                                          auth.token!);
                                                } else if (value == 'watch') {
                                                  await sessionProvider
                                                      .toggleWatch(session.id,
                                                          auth.token!);
                                                }
                                              },
                                              itemBuilder: (context) {
                                                final hasPr = session.outputs !=
                                                        null &&
                                                    session.outputs!.any((o) =>
                                                        o.pullRequest != null);
                                                return [
                                                  if (hasPr) ...[
                                                    const PopupMenuItem(
                                                      value: 'pr',
                                                      child: Row(children: [
                                                        Icon(Icons.merge_type,
                                                            color:
                                                                Colors.purple),
                                                        SizedBox(width: 8),
                                                        Text(
                                                            'View Pull Request')
                                                      ]),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'pr_read',
                                                      child: Row(children: [
                                                        Icon(
                                                            Icons
                                                                .mark_email_read,
                                                            color:
                                                                Colors.purple),
                                                        SizedBox(width: 8),
                                                        Text(
                                                            'Open PR & Mark Read')
                                                      ]),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'copy_pr_url',
                                                      child: Row(children: [
                                                        Icon(Icons.copy, color: Colors.purple),
                                                        SizedBox(width: 8),
                                                        Text('Copy PR Link'),
                                                      ]),
                                                    ),
                                                  ],
                                                  if (metadata.isUnread)
                                                    const PopupMenuItem(
                                                      value: 'mark_read',
                                                      child: Row(children: [
                                                        Icon(Icons
                                                            .mark_email_read),
                                                        SizedBox(width: 8),
                                                        Text('Mark as Read')
                                                      ]),
                                                    )
                                                  else
                                                    const PopupMenuItem(
                                                      value: 'mark_unread',
                                                      child: Row(children: [
                                                        Icon(Icons
                                                            .mark_email_unread),
                                                        SizedBox(width: 8),
                                                        Text('Mark as Unread')
                                                      ]),
                                                    ),
                                                  if (metadata.isWatched)
                                                    const PopupMenuItem(
                                                      value: 'watch',
                                                      child: Row(children: [
                                                        Icon(Icons
                                                            .visibility_off),
                                                        SizedBox(width: 8),
                                                        Text('Unwatch')
                                                      ]),
                                                    )
                                                  else
                                                    const PopupMenuItem(
                                                      value: 'watch',
                                                      child: Row(children: [
                                                        Icon(Icons.visibility),
                                                        SizedBox(width: 8),
                                                        Text('Watch')
                                                      ]),
                                                    ),
                                                  const PopupMenuItem(
                                                    value: 'reply',
                                                    child: Row(children: [
                                                      Icon(Icons.reply),
                                                      SizedBox(width: 8),
                                                      Text('Quick Reply')
                                                    ]),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'view_prompt',
                                                    child: Row(children: [
                                                      Icon(Icons.description),
                                                      SizedBox(width: 8),
                                                      Text('View Prompt')
                                                    ]),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'refresh',
                                                    child: Row(children: [
                                                      Icon(Icons.refresh),
                                                      SizedBox(width: 8),
                                                      Text('Refresh Session')
                                                    ]),
                                                  ),
                                                  if (session.url != null)
                                                    const PopupMenuItem(
                                                      value: 'browser',
                                                      child: Row(children: [
                                                        Icon(Icons
                                                            .open_in_browser),
                                                        SizedBox(width: 8),
                                                        Text('Open in Browser')
                                                      ]),
                                                    ),
                                                  if (session.url != null)
                                                    const PopupMenuItem(
                                                      value: 'copy_jules_url',
                                                      child: Row(children: [
                                                        Icon(Icons.copy),
                                                        SizedBox(width: 8),
                                                        Text('Copy Jules Link'),
                                                      ]),
                                                    ),
                                                  const PopupMenuItem(
                                                    value: 'source',
                                                    child: Row(children: [
                                                      Icon(Icons.source),
                                                      SizedBox(width: 8),
                                                      Text('View Source Repo')
                                                    ]),
                                                  ),
                                                  if (isDevMode)
                                                    const PopupMenuItem(
                                                      value: 'raw',
                                                      child: Row(children: [
                                                        Icon(Icons
                                                            .developer_mode),
                                                        SizedBox(width: 8),
                                                        Text('Dev Tools')
                                                      ]),
                                                    ),
                                                ];
                                              },
                                            ),
                                          ]),
                                          const SizedBox(height: 8),
                                          SessionMetaPills(
                                            session: session,
                                            compact: true,
                                            onAddFilter: (token) {
                                              _addFilterToken(token);
                                              ScaffoldMessenger.of(context)
                                                  .hideCurrentSnackBar();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Added filter: ${token.label}"),
                                                duration:
                                                    const Duration(seconds: 1),
                                              ));
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
                                                  top: 8.0),
                                              child: LinearProgressIndicator(
                                                value: session.currentStep! /
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
        );
      },
    );
  }

  void _showTileMenu(BuildContext context, Session session,
      CacheMetadata metadata, bool isDevMode,
      {Offset? position}) {
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

    showMenu(context: context, position: finalPosition, items: [
      PopupMenuItem(
        child: Row(
          children: [
            Icon(metadata.isHidden ? Icons.visibility : Icons.visibility_off),
            const SizedBox(width: 8),
            Text(metadata.isHidden ? 'Unhide' : 'Hide'),
          ],
        ),
        onTap: () async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await Provider.of<SessionProvider>(context, listen: false)
              .toggleHidden(session.id, auth.token!);
        },
      ),
      if (session.url != null)
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
          session.outputs!.any((o) => o.pullRequest != null))
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.merge_type),
              SizedBox(width: 8),
              Text('Open PR & Mark Read'),
            ],
          ),
          onTap: () async {
            final pr = session.outputs!
                .firstWhere((o) => o.pullRequest != null)
                .pullRequest!;
            if (await launchUrl(Uri.parse(pr.url))) {
              _markAsRead(session);
            }
          },
        ),
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
      if (isDevMode)
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
    ]).then((value) {
      if (value == 'source' && session.sourceContext.source.isNotEmpty) {
        _openSourceUrl(session.sourceContext.source);
      }
    });
  }
}

// Removed ListItem classes as they are no longer needed
