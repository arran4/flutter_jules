import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';
import '../../models.dart';
import '../../models/api_exchange.dart';
import '../widgets/api_viewer.dart';
import '../widgets/model_viewer.dart';
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
  DateTime? _lastFetchTime;

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
    int itemCount;
    if (_isLoading) {
      itemCount = 3; // Header, Spinner, Footer
    } else if (_error != null) {
      itemCount = 3; // Header, Error, Footer
    } else {
      itemCount = _activities.length + 2; // Header, Activities, Footer
    }

    final isDevMode = Provider.of<DevModeProvider>(context).isDevMode;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          widget.session.title ?? 'Session Detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isDevMode)
             IconButton(
               icon: const Icon(Icons.data_object),
               tooltip: 'View Session Data',
               onPressed: () {
                 showDialog(
                   context: context,
                   builder: (context) => ModelViewer(
                     data: widget.session.toJson(),
                     title: 'Session Data',
                   ),
                 );
               },
             ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: _fetchActivities,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Header
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "State: ${widget.session.state.toString().split('.').last}"),
                      Text("Prompt: ${widget.session.prompt}"),
                      if (_lastFetchTime != null)
                        Text(
                          'Last updated: ${DateFormat.Hms().format(_lastFetchTime!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Divider(),
              ],
            );
          }

          // Footer (Chat Input)
          if (index == itemCount - 1) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration:
                          const InputDecoration(hintText: "Send message..."),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _sendMessage(value);
                        }
                      },
                    ),
                  ),
                  if (widget.session.state ==
                      SessionState.AWAITING_PLAN_APPROVAL)
                    ElevatedButton(
                        onPressed: _approvePlan,
                        child: const Text("Approve Plan"))
                ],
              ),
            );
          }

          // Middle Content
          if (_isLoading) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    SelectableText(_error!, textAlign: TextAlign.center),
                    TextButton(
                        onPressed: _fetchActivities,
                        child: const Text("Retry"))
                  ],
                ),
              ),
            );
          }

          // Activity Item
          final activity = _activities[index - 1];
          final item = ActivityItem(activity: activity);

          if (isDevMode) {
            return GestureDetector(
              onLongPress: () => _showContextMenu(context, activity: activity),
              onSecondaryTap: () =>
                  _showContextMenu(context, activity: activity),
              child: item,
            );
          } else {
            return item;
          }
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, {Activity? activity}) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Dev Tools'),
        children: [
          if (_lastExchange != null)
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
              child: const Text('View Source (List API)'),
            ),
          if (activity != null)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => ModelViewer(
                    data: activity.toJson(),
                    title: 'Activity Data',
                  ),
                );
              },
              child: const Text('View Activity Data'),
            ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => ModelViewer(
                  data: widget.session.toJson(),
                  title: 'Session Data',
                ),
              );
            },
            child: const Text('View Session Data'),
          ),
        ],
      ),
    );
  }
}
