import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/data_provider.dart';
import '../../models.dart';
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
      Provider.of<DataProvider>(context, listen: false).fetchSessions();
    });
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
                  // Force refresh after creating
                  if (mounted) {
                    Provider.of<DataProvider>(context, listen: false).fetchSessions(force: true);
                  }
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
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final sessions = provider.sessions;
        final isLoading = provider.isSessionsLoading;
        final error = provider.sessionsError;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sessions'),
            actions: [
               IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: () => provider.fetchSessions(force: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Stack(
            children: [
              if (sessions.isEmpty && isLoading)
                const Center(child: CircularProgressIndicator())
              else if (sessions.isEmpty && error != null)
                Center(
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
                          error,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => provider.fetchSessions(force: true),
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
              else
                ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
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
                ),
               if (sessions.isNotEmpty && isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
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
