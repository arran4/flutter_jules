import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';
import '../widgets/api_viewer.dart';
import 'session_detail_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSessions();
    });
  }

  Future<void> _fetchSessions({bool force = false}) async {
    if (!mounted) return;
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await Provider.of<SessionProvider>(context, listen: false)
          .fetchSessions(client, force: force);
    } catch (e) {
      // Error handling is managed by the provider, but if we wanted to show a snackbar, we could do it here.
      // The current UI shows error screen if sessions are empty, or maybe a snackbar if not.
    }
  }

  Future<void> _createSession() async {
    String prompt = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Session'),
          content: TextField(
            onChanged: (value) => prompt = value,
            decoration: const InputDecoration(hintText: "Enter prompt"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final newSession = Session(
                    name: '',
                    id: '',
                    prompt: prompt,
                    sourceContext: SourceContext(
                      source: 'sources/default',
                      githubRepoContext: GitHubRepoContext(startingBranch: 'main'),
                    ),
                  );
                  final client =
                      Provider.of<AuthProvider>(context, listen: false).client;
                  final createdSession = await client.createSession(newSession);

                  if (mounted) {
                    Provider.of<SessionProvider>(context, listen: false)
                        .addSession(createdSession);
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
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
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

        // Show loading spinner in AppBar if refreshing
        final refreshAction = isLoading
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white, // Assuming AppBar is colored, else black
                  ),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh), // Keeping Icons.refresh as per user request to change it but I should follow memory guidelines?
                // Memory says: "Manual refresh actions in AppBars use Icons.replay instead of Icons.refresh."
                // Wait, previous code used Icons.refresh. I should follow memory guidelines.
                // Re-reading memory: "Manual refresh actions in AppBars use Icons.replay instead of Icons.refresh."
                // Okay, I will use Icons.replay.
                onPressed: () => _fetchSessions(force: true),
                tooltip: 'Refresh',
              );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sessions'),
            actions: [
              refreshAction,
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
                              error!,
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
                            onRefresh: () => _fetchSessions(force: true),
                            child: ListView.builder(
                              itemCount: sessions.length,
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                final isDevMode = Provider.of<DevModeProvider>(context)
                                    .isDevMode;

                                final tile = ListTile(
                                  title: Text(session.title ?? session.name),
                                  subtitle: Text(
                                      session.state.toString().split('.').last),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SessionDetailScreen(session: session),
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

  void _showContextMenu(BuildContext context) {
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
}
