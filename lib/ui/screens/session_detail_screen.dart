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
  late Session _session;
  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;
  ApiExchange? _lastExchange;
  DateTime? _lastFetchTime;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchActivities();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivities() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Add timeout to prevent indefinite hanging
      await Future.any([
        _performFetchActivities(),
        Future.delayed(const Duration(seconds: 30)).then((_) {
          throw Exception(
              'Request timed out after 30 seconds. Please check your connection and try again.');
        }),
      ]);
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

  Future<void> _performFetchActivities() async {
    final client = Provider.of<AuthProvider>(context, listen: false).client;
    final devMode = Provider.of<DevModeProvider>(context, listen: false);
    final enableLogging = devMode.enableApiLogging;

    // Fetch session details first
    Session? updatedSession;
    try {
      // if (enableLogging) {
      //   debugPrint('DEBUG: Fetching session details for ${widget.session.name}');
      // }
      updatedSession = await client.getSession(widget.session.name);
      // if (enableLogging) debugPrint('DEBUG: Session details fetched successfully');
    } catch (e) {
      // if (enableLogging) debugPrint('DEBUG: Failed to fetch session details: $e');
      throw Exception('Failed to load session details: $e');
    }

    // Then fetch activities
    List<Activity> activities;
    try {
      // if (enableLogging) {
      //   debugPrint('DEBUG: Fetching activities for ${widget.session.name}');
      // }
      activities = await client.listActivities(
        widget.session.name,
        onDebug: (exchange) {
          if (enableLogging) {
            // debugPrint(
            //     'DEBUG: API call - ${exchange.method} ${exchange.url} - Status: ${exchange.statusCode}');
          }
          _lastExchange = exchange;
        },
      );
      // if (enableLogging) {
      //   debugPrint(
      //       'DEBUG: Activities fetched successfully - count: ${activities.length}');
      // }
    } catch (e) {
      // if (enableLogging) debugPrint('DEBUG: Failed to fetch activities: $e');
      throw Exception('Failed to load conversation history: $e');
    }

    if (mounted) {
      setState(() {
        _activities = activities;
        _session = updatedSession!;
        _lastFetchTime = DateTime.now();
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await client.sendMessage(_session.name, message);
      _messageController.clear();
      _fetchActivities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _approvePlan() async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await client.approvePlan(_session.name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Plan Approved")));
      }
      _fetchActivities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
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
          _session.title ?? 'Session Detail',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: 'View Session Data',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ModelViewer(
                  data: _session.toJson(),
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
                          "State: ${_session.state.toString().split('.').last}"),
                      Text("Prompt: ${_session.prompt}"),
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
            final hasText = _messageController.text.isNotEmpty;
            final canApprove =
                _session.state == SessionState.AWAITING_PLAN_APPROVAL;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration:
                          const InputDecoration(hintText: "Send message..."),
                      onChanged: (text) => setState(() {}),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _sendMessage(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _sendMessage(_messageController.text),
                      tooltip: 'Send Message',
                    )
                  else if (canApprove)
                    ElevatedButton(
                        onPressed: _approvePlan,
                        child: const Text("Approve Plan"))
                  else
                    const IconButton(
                      icon: Icon(Icons.send),
                      onPressed: null,
                      tooltip: 'Send Message (Empty)',
                    ),
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
                        onPressed: _fetchActivities, child: const Text("Retry"))
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
