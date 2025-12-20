import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../models.dart';
import '../../models/api_exchange.dart';
import '../widgets/api_viewer.dart';
import '../widgets/activity_item.dart';

class SessionDetailScreen extends StatefulWidget {
  final Session session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchActivities();
    });
  }

  Future<void> _fetchActivities() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final activities = await client.listActivities(
        widget.session.name,
        onDebug: (exchange) {
          _lastExchange = exchange;
        },
      );
      if (mounted) {
        setState(() {
          _activities = activities;
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
  
  Future<void> _sendMessage(String message) async {
      try {
          final client = Provider.of<AuthProvider>(context, listen: false).client;
          await client.sendMessage(widget.session.name, message);
          _fetchActivities(); 
      } catch (e) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }
  
  Future<void> _approvePlan() async {
      try {
          final client = Provider.of<AuthProvider>(context, listen: false).client;
          await client.approvePlan(widget.session.name);
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Approved")));
          }
          _fetchActivities();
      } catch (e) {
           if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title ?? 'Session Detail'),
        actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchActivities,
              tooltip: 'Refresh',
            )
        ],
      ),
      body: Column(
        children: [
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 8),
                              SelectableText(_error!, textAlign: TextAlign.center),
                              TextButton(onPressed: _fetchActivities, child: const Text("Retry"))
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          final isDevMode = Provider.of<DevModeProvider>(context).isDevMode;
                          final item = ActivityItem(activity: activity);

                          if (isDevMode) {
                            return GestureDetector(
                              onLongPress: () => _showContextMenu(context),
                              onSecondaryTap: () => _showContextMenu(context),
                              child: item,
                            );
                          } else {
                            return item;
                          }
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
                children: [
                    Expanded(child: TextField(
                        decoration: const InputDecoration(hintText: "Send message..."),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _sendMessage(value);
                          }
                        },
                    )),
                    if (widget.session.state == SessionState.AWAITING_PLAN_APPROVAL)
                        ElevatedButton(onPressed: _approvePlan, child: const Text("Approve Plan"))
                ],
            ),
          )
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    if (_lastExchange == null) return;

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
