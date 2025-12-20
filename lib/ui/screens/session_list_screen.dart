import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../models.dart';
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

  // Filtering
  Set<SessionState>? _allowedStatuses;

  // Grouping
  List<String> _groupingLevels = ['Status']; // Default to Status

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
      final sessions = await client.listSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
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

  void _showFilterDialog() {
    final allStatuses =
        _sessions.map((s) => s.state ?? SessionState.STATE_UNSPECIFIED).toSet();
    final currentlyAllowed = _allowedStatuses ?? allStatuses;

    final tempAllowed = Set<SessionState>.from(currentlyAllowed);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allStatuses.map((status) {
                    return CheckboxListTile(
                      title: Text(status.toString().split('.').last),
                      value: tempAllowed.contains(status),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempAllowed.add(status);
                          } else {
                            tempAllowed.remove(status);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      tempAllowed.addAll(allStatuses);
                    });
                  },
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      tempAllowed.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      _allowedStatuses = tempAllowed;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGroupingDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Group By'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _groupingLevels = [];
                });
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  if (_groupingLevels.isEmpty) const Icon(Icons.check),
                  const SizedBox(width: 8),
                  const Text('None'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                setState(() {
                  _groupingLevels = ['Status'];
                });
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  if (_groupingLevels.contains('Status'))
                    const Icon(Icons.check),
                  const SizedBox(width: 8),
                  const Text('Status'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSessionList() {
    var filtered = _sessions;
    if (_allowedStatuses != null) {
      filtered = filtered
          .where((s) => _allowedStatuses!
              .contains(s.state ?? SessionState.STATE_UNSPECIFIED))
          .toList();
    }

    if (filtered.isEmpty) {
      return const Center(child: Text("No sessions found"));
    }

    if (_groupingLevels.contains('Status')) {
      final grouped = <SessionState, List<Session>>{};
      for (var s in filtered) {
        final state = s.state ?? SessionState.STATE_UNSPECIFIED;
        grouped.putIfAbsent(state, () => []).add(s);
      }

      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) => a.index.compareTo(b.index));

      return ListView.builder(
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final state = sortedKeys[index];
          final sessions = grouped[state]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                width: double.infinity,
                child: Text(
                  state.toString().split('.').last,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...sessions.map((session) => ListTile(
                    title: Text(session.title ?? session.name),
                    subtitle: Text(session.state.toString().split('.').last),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SessionDetailScreen(session: session),
                        ),
                      );
                    },
                  )),
            ],
          );
        },
      );
    } else {
      return ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final session = filtered[index];
          return ListTile(
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
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.group_work),
            onPressed: _showGroupingDialog,
            tooltip: 'Group By',
          ),
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
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 60),
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
              : _buildSessionList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        tooltip: 'Create Session',
        child: const Icon(Icons.add),
      ),
    );
  }
}
