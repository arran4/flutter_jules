import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/search_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../services/session_provider.dart';
import '../../services/source_provider.dart';
import '../../services/settings_provider.dart';
import '../../services/cache_service.dart';
import '../../models.dart';
import '../../models/cache_metadata.dart';
import '../widgets/api_viewer.dart';
import '../widgets/model_viewer.dart';
import '../widgets/new_session_dialog.dart';
import 'session_detail_screen.dart';
import '../widgets/session_meta_pills.dart';
import '../widgets/session_preview_modal.dart';

class SessionListScreen extends StatefulWidget {
  final String? sourceFilter;

  const SessionListScreen({super.key, this.sourceFilter});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final Set<SessionState> _statusFilters = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions({bool force = false}) async {
    if (!mounted) return;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);

      await sessionProvider.fetchSessions(auth.client,
          force: force, authToken: auth.token);
    } catch (e) {
      // Provider handles error state
    }
  }

  Future<void> _createSession() async {
    final Session? sessionToCreate = await showDialog<Session>(
      context: context,
      builder: (context) => NewSessionDialog(sourceFilter: widget.sourceFilter),
    );

    if (sessionToCreate == null) return;
    if (!mounted) return;

    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await client.createSession(sessionToCreate);
      // Trigger refresh
      _fetchSessions(force: true);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Creating Session'),
            content: SingleChildScrollView(child: SelectableText(e.toString())),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          ),
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

  void _showFilterDialog() {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final allSessions = sessionProvider.items.map((i) => i.data).toList();
    final allStatuses = allSessions
        .map((s) => s.state)
        .whereType<SessionState>()
        .toSet()
        .toList();
    allStatuses.sort((a, b) => a.index.compareTo(b.index));

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allStatuses.map((status) {
                    return CheckboxListTile(
                      title: Text(status.displayName),
                      subtitle: Text(status.description,
                          style: const TextStyle(fontSize: 12)),
                      value: _statusFilters.contains(status) ||
                          _statusFilters.isEmpty,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (_statusFilters.isEmpty) {
                              _statusFilters.add(status);
                            } else {
                              _statusFilters.add(status);
                            }
                          } else {
                            if (_statusFilters.isEmpty) {
                              _statusFilters.addAll(allStatuses);
                              _statusFilters.remove(status);
                            } else {
                              _statusFilters.remove(status);
                            }
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _statusFilters.clear();
                    });
                    setState(() {});
                  },
                  child: const Text('Clear Filter'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          });
        });
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

        List<CachedItem<Session>> displayItems = cachedItems;

        if (widget.sourceFilter != null) {
          displayItems = displayItems
              .where((i) => i.data.sourceContext.source == widget.sourceFilter)
              .toList();
        }
        if (_statusFilters.isNotEmpty) {
          displayItems = displayItems
              .where((i) =>
                  i.data.state != null && _statusFilters.contains(i.data.state))
              .toList();
        }

        // Searching (Naively filtering cached items)
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          displayItems = displayItems.where((i) {
            final s = i.data;
            return (s.title?.toLowerCase().contains(query) ?? false) ||
                (s.name.toLowerCase().contains(query)) ||
                (s.id.toLowerCase().contains(query)) ||
                (s.state.toString().toLowerCase().contains(query));
          }).toList();
        }

        // Sorting (ensure time sort)
        displayItems.sort((a, b) {
          final timeA = _getEffectiveTime(a);
          final timeB = _getEffectiveTime(b);
          return timeB.compareTo(timeA);
        });

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
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => _fetchSessions(force: true),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: _showFilterDialog,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.pushNamed(context, '/settings');
                  } else if (value == 'sources') {
                    Navigator.pushNamed(context, '/sources_raw');
                  } else if (value == 'raw_data') {
                    _viewRawData(context);
                  }
                },
                itemBuilder: (context) => [
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
                        Text('Repositories'),
                      ],
                    ),
                  ),
                ],
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
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Sessions',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        if (lastFetchTime != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Last refreshed: ${DateFormat.Hms().format(lastFetchTime!)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => _fetchSessions(force: true),
                            child: ListView.builder(
                              itemCount: displayItems.length,
                              itemBuilder: (context, index) {
                                final cachedItem = displayItems[index];
                                final session = cachedItem.data;
                                final metadata = cachedItem.metadata;
                                final isDevMode =
                                    Provider.of<DevModeProvider>(context)
                                        .isDevMode;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: InkWell(
                                    onTap: () {
                                      _markAsRead(session);
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  SessionDetailScreen(
                                                      session: session)));
                                    },
                                    onLongPress: () {
                                      if (isDevMode) {
                                        _showContextMenu(context,
                                            session: session);
                                      }
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
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text('NEW',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                if (metadata.isUpdated &&
                                                    !metadata.isNew)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text('UPDATED',
                                                        style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),
                                                if (metadata.isUnread &&
                                                    !metadata.isNew &&
                                                    !metadata.isUpdated)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text('UNREAD',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  ),

                                                // Render custom labels
                                                for (final label
                                                    in metadata.labels)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade700,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                        label.toUpperCase(),
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
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
                                            if (session.outputs != null &&
                                                session.outputs!.any((o) =>
                                                    o.pullRequest != null))
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.merge_type),
                                                tooltip: 'View Pull Request',
                                                color: Colors.purple,
                                                onPressed: () {
                                                  final pr = session.outputs!
                                                      .firstWhere((o) =>
                                                          o.pullRequest != null)
                                                      .pullRequest!;
                                                  launchUrl(Uri.parse(pr.url));
                                                },
                                              ),
                                          ]),
                                          const SizedBox(height: 8),
                                          SessionMetaPills(
                                              session: session, compact: true),
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
}

// Removed ListItem classes as they are no longer needed
