import 'package:flutter/material.dart';
import '../../services/jules_client.dart';
import '../../models.dart';
import '../widgets/activity_item.dart';

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
          _fetchActivities(); 
      } catch (e) {
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
      }
  }
  
  Future<void> _approvePlan() async {
      try {
          await _client.approvePlan(widget.session.name);
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
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchActivities)
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
                    ? Center(child: Text('Error: $_error'))
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
