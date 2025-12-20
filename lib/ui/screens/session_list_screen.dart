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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSessions,
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSessions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        tooltip: 'Create Session',
        child: const Icon(Icons.add),
      ),
    );
  }
}
