import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../models.dart';
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
      final activities = await client.listActivities(widget.session.name);
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
        leading: const BackButton(),
        actions: [
            IconButton(
              icon: const Icon(Icons.replay),
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
                          return ActivityItem(activity: activity);
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
}
