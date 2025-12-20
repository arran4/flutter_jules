import 'package:flutter/material.dart';
import 'jules_client.dart';
import 'models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jules API Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const JulesHomePage(),
    );
  }
}

class JulesHomePage extends StatefulWidget {
  const JulesHomePage({super.key});

  @override
  State<JulesHomePage> createState() => _JulesHomePageState();
}

class _JulesHomePageState extends State<JulesHomePage> {
  // Replace with actual API key/token
  final JulesClient _client = JulesClient(apiKey: 'YOUR_API_KEY');
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    SessionListScreen(),
    SourceListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Sessions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.source),
            label: 'Sources',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- Sessions Screen ---

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final JulesClient _client = JulesClient(apiKey: 'YOUR_API_KEY');
  List<Session> _sessions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _client.listSessions();
      setState(() {
        _sessions = sessions;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createSession() async {
    // Example: Create session dialog
    // Ideally this would be a separate screen where user can input prompt and pick a source.
    // For now, we'll just show a dialog to input prompt, assuming a hardcoded source or picking the first one.
    
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
                   // This assumes a valid source name is known. 
                   // In a real app, you'd fetch sources and let user pick.
                   final newSession = Session(
                    name: '',
                    id: '',
                    prompt: prompt,
                    sourceContext: SourceContext(
                      source: 'sources/default', // Placeholder
                      githubRepoContext: GitHubRepoContext(startingBranch: 'main'),
                    ),
                  );
                  await _client.createSession(newSession);
                  _fetchSessions();
                } catch (e) {
                   if(mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create: $e')),
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
              ? Center(child: Text('Error: $_error'))
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

// --- Sources Screen ---

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  final JulesClient _client = JulesClient(apiKey: 'YOUR_API_KEY');
  List<Source> _sources = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sources = await _client.listSources();
      setState(() {
        _sources = sources;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSources,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    return ListTile(
                      title: Text(source.githubRepo?.repo ?? source.name),
                      subtitle: Text(source.githubRepo?.owner ?? ''),
                      leading: const Icon(Icons.code),
                    );
                  },
                ),
    );
  }
}

// --- Session Detail Screen ---

class SessionDetailScreen extends StatefulWidget {
  final Session session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final JulesClient _client = JulesClient(apiKey: 'YOUR_API_KEY');
  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final activities = await _client.listActivities(widget.session.name);
      setState(() {
        _activities = activities;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _sendMessage(String message) async {
      try {
          await _client.sendMessage(widget.session.name, message);
          _fetchActivities(); // Refresh to see new message (eventually)
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
  }
  
  Future<void> _approvePlan() async {
      try {
          await _client.approvePlan(widget.session.name);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Approved")));
          _fetchActivities();
      } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title ?? 'Session Detail'),
        actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchActivities)
        ],
      ),
      body: Column(
        children: [
          // Basic Info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text("State: ${widget.session.state.toString().split('.').last}"),
                    Text("Prompt: ${widget.session.prompt}"),
                ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : ListView.builder(
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return ActivityItem(activity: activity);
                        },
                      ),
          ),
          // Simple input for sending messages
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
                children: [
                    Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Send message..."),
                        onSubmitted: _sendMessage,
                    )),
                    IconButton(icon: const Icon(Icons.send), onPressed: () {
                        // In real app, bind text controller
                    }),
                    if (widget.session.state == SessionState.AWAITING_PLAN_APPROVAL)
                        ElevatedButton(onPressed: _approvePlan, child: const Text("Approve Plan"))
                ],
            ),
          )
        ],
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final Activity activity;

  const ActivityItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    String title = "Activity";
    String description = activity.description;
    IconData icon = Icons.info;

    if (activity.agentMessaged != null) {
      title = "Agent";
      description = activity.agentMessaged!.agentMessage;
      icon = Icons.smart_toy;
    } else if (activity.userMessaged != null) {
      title = "User";
      description = activity.userMessaged!.userMessage;
      icon = Icons.person;
    } else if (activity.planGenerated != null) {
      title = "Plan Generated";
      description = "Steps: ${activity.planGenerated!.plan.steps.length}";
      icon = Icons.list_alt;
    } else if (activity.planApproved != null) {
      title = "Plan Approved";
      icon = Icons.check_circle;
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      description = activity.progressUpdated!.description;
      icon = Icons.update;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
