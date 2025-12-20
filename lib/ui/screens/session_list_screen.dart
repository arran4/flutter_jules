import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../utils/search_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';
import '../widgets/api_viewer.dart';
import '../widgets/new_session_dialog.dart';
import 'session_detail_screen.dart';

class SessionListScreen extends StatefulWidget {
  final String? sourceFilter;

  const SessionListScreen({super.key, this.sourceFilter});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  // Local state for searching/filtering
  bool _groupByStatus = true;
  final Set<SessionState> _statusFilters = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild when search changes
    _searchController.addListener(() {
      setState(() {});
    });

    // Initial fetch handled by addPostFrameCallback to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSessions();
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
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

      // Use the provider to fetch. It updates its own state.
      await sessionProvider.fetchSessions(client, force: force);

      if (mounted) {
        setState(() {}); // Trigger rebuild to reflect new data
      }
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
      final createdSession = await client.createSession(sessionToCreate);

      if (mounted) {
        Provider.of<SessionProvider>(context, listen: false)
            .addSession(createdSession);
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Creating Session'),
            content: SingleChildScrollView(
              child: SelectableText(e.toString()),
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

  void _showContextMenu(BuildContext context) {
    // If we want to show the last exchange for the list call
    final lastExchange =
        Provider.of<SessionProvider>(context, listen: false).lastExchange;

    if (lastExchange == null) return;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dev Tools'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => ApiViewer(exchange: lastExchange),
              );
            },
            child: const Text('View Source'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
     // Get all unique statuses from the FULL list (not filtered)
     final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
     final allSessions = sessionProvider.sessions;
     final allStatuses = allSessions.map((s) => s.state).whereType<SessionState>().toSet().toList();
     allStatuses.sort((a, b) => a.index.compareTo(b.index));

     showDialog(
       context: context,
       builder: (context) {
         // This StatefulBuilder updates the dialog content
         return StatefulBuilder(
           builder: (context, setDialogState) {
             return AlertDialog(
               title: const Text('Filter by Status'),
               content: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: allStatuses.map((status) {
                     return CheckboxListTile(
                       title: Text(status.toString().split('.').last),
                       value: _statusFilters.contains(status) || _statusFilters.isEmpty,
                       onChanged: (bool? value) {
                         // Update local filter state
                         setDialogState(() {
                           if (value == true) {
                             if (_statusFilters.isEmpty) {
                               // Start with only this one
                               _statusFilters.add(status);
                             } else {
                               _statusFilters.add(status);
                             }
                           } else {
                             // Unchecking.
                             if (_statusFilters.isEmpty) {
                               // "Select All" was implicit. We need to populate with all OTHER statuses.
                               _statusFilters.addAll(allStatuses);
                               _statusFilters.remove(status);
                             } else {
                               _statusFilters.remove(status);
                             }
                           }
                         });

                         // Update the main screen (underneath the dialog)
                         // We need to call the main state's setState
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
                       _statusFilters.clear(); // Clear means "Show All"
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
           }
         );
       }
     );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final sessions = sessionProvider.sessions;
        final isLoading = sessionProvider.isFetching;
        final error = sessionProvider.error;
        final lastFetchTime = sessionProvider.lastFetchTime;

        // Re-calculating display list in build to ensure reactivity
        List<Session> displaySessions = sessions;
        if (widget.sourceFilter != null) {
          displaySessions = displaySessions.where((s) => s.sourceContext.source == widget.sourceFilter).toList();
        }
        if (_statusFilters.isNotEmpty) {
          displaySessions = displaySessions.where((s) => s.state != null && _statusFilters.contains(s.state)).toList();
        }
        // Search
        if (_searchController.text.isNotEmpty) {
           displaySessions = filterAndSort(
            items: displaySessions,
            query: _searchController.text,
            accessors: [
              (session) => session.title,
              (session) => session.name,
              (session) => session.id,
              (session) => session.state.toString().split('.').last,
            ],
          );
        }

        // Sort
        if (_groupByStatus) {
           displaySessions.sort((a, b) {
             // Handle null states if any
             final stateA = a.state?.index ?? -1;
             final stateB = b.state?.index ?? -1;

             int cmp = stateA.compareTo(stateB);
             if (cmp != 0) return cmp;

             // Secondary sort
             final dateA = DateTime.tryParse(a.createTime ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
             final dateB = DateTime.tryParse(b.createTime ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
             return dateB.compareTo(dateA);
           });
        } else {
           displaySessions.sort((a, b) {
             final dateA = DateTime.tryParse(a.createTime ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
             final dateB = DateTime.tryParse(b.createTime ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
             return dateB.compareTo(dateA);
           });
        }

        // Determine items for ListView (headers + items)
        final List<ListItem> items = [];
        if (_groupByStatus) {
           SessionState? lastState;
           // We might have null states
           for (var session in displaySessions) {
             if (session.state != lastState) {
               items.add(HeaderItem(session.state?.toString().split('.').last ?? 'Unknown'));
               lastState = session.state;
             }
             items.add(SessionItem(session));
           }
        } else {
           for (var session in displaySessions) {
             items.add(SessionItem(session));
           }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sessions'),
            actions: [
               IconButton(
                icon: Icon(_groupByStatus ? Icons.layers_clear : Icons.layers),
                tooltip: _groupByStatus ? 'Ungroup' : 'Group by Status',
                onPressed: () {
                  setState(() {
                    _groupByStatus = !_groupByStatus;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: _showFilterDialog,
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: () => _fetchSessions(force: true),
                  tooltip: 'Refresh',
                ),
            ],
          ),
          body: (sessions.isEmpty && isLoading)
              ? const Center(child: CircularProgressIndicator())
              : (sessions.isEmpty && error != null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              'Error Loading Sessions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              error,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _fetchSessions(force: true),
                                  child: const Text('Retry'),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton(
                                  onPressed: () {
                                    Provider.of<AuthProvider>(context, listen: false)
                                        .logout();
                                  },
                                  child: const Text('Change Token'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
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
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Last updated: ${DateFormat.Hms().format(lastFetchTime)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchSessions,
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is HeaderItem) {
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            } else if (item is SessionItem) {
                              final session = item.session;
                              final isDevMode = Provider.of<DevModeProvider>(context).isDevMode;

                              final tile = ListTile(
                                title: Text(
                                  session.title ?? session.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(session.state.toString().split('.').last),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SessionDetailScreen(session: session),
                                    ),
                                  );
                                },
                                onLongPress: isDevMode
                                    ? () => _showContextMenu(context)
                                    : null,
                              );

                              if (isDevMode) {
                                return GestureDetector(
                                  onSecondaryTap: () => _showContextMenu(context),
                                  child: tile,
                                );
                              } else {
                                return tile;
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _createSession,
            tooltip: 'Create Session',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

// Helper classes for mixed list
abstract class ListItem {}

class HeaderItem implements ListItem {
  final String title;
  HeaderItem(this.title);
}

class SessionItem implements ListItem {
  final Session session;
  SessionItem(this.session);
}
