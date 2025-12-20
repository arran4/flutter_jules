import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../models.dart';
import '../../models/api_exchange.dart';
import '../widgets/api_viewer.dart';
import 'session_detail_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<Session> _sessions = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSessions();
    });
  }

  Future<void> _fetchSessions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final sessions = await client.listSessions(
        onDebug: (exchange) {
          _lastExchange = exchange;
        },
      );
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  final client = Provider.of<AuthProvider>(context, listen: false).client;
                  await client.createSession(newSession);
                  _fetchSessions();
                } catch (e) {
                   if(mounted) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSessions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Sessions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _fetchSessions,
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton(
                              onPressed: () {
                                Provider.of<AuthProvider>(context, listen: false).logout();
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
                    if (_lastFetchTime != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Last updated: ${DateFormat.Hms().format(_lastFetchTime!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchSessions,
                        child: ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final isDevMode = Provider.of<DevModeProvider>(context).isDevMode;

                    final tile = ListTile(
                      title: Text(session.title ?? session.name),
                      subtitle: Text(session.state.toString().split('.').last),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SessionDetailScreen(session: session),
                          ),
                        );
                      },
                      onLongPress: isDevMode ? () => _showContextMenu(context) : null,
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
                            );
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
  }

  void _showContextMenu(BuildContext context) {
    if (_lastExchange == null) return;

    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    // We can't easily get the exact position of the tap here without using GestureDetector details,
    // so we'll just show it in the center or let showMenu handle it if we passed position.
    // For simplicity with list items, showing a Dialog directly might be better UX for "context menu" on mobile if we can't position it.
    // However, the requirement says "context menu".
    // Let's assume we want to show a popup menu.
    // But showMenu requires position.
    // Let's use showModalBottomSheet or Dialog for simplicity since we lack position data here easily without wrapping every item in detailed gesture detector.
    // Actually, let's use a simple Dialog with options as the "Menu".

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dev Tools'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              if (_lastExchange != null) {
                showDialog(
                  context: context,
                  builder: (context) => ApiViewer(exchange: _lastExchange!),
                );
              }
            },
            child: const Text('View Source'),
          ),
        ],
      ),
    );
  }
}
