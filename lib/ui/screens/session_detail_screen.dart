import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/cache_service.dart';
import '../../services/auth_provider.dart';
import '../../services/session_provider.dart';
import '../../utils/time_helper.dart'; // Import time helper
import '../../services/dev_mode_provider.dart';
import '../../services/message_queue_provider.dart';
import '../../services/settings_provider.dart';
import '../../models.dart';
import '../../models/api_exchange.dart';
import '../widgets/api_viewer.dart';
import '../widgets/model_viewer.dart';
import '../widgets/activity_item.dart';
import '../widgets/activity_helper.dart';
import '../widgets/new_session_dialog.dart';
import '../widgets/session_meta_pills.dart';
import '../widgets/tag_management_dialog.dart';
import '../session_helpers.dart';
import 'dart:convert';
import '../../services/exceptions.dart';

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
  bool _isPromptExpanded = false;
  String? _error;
  String _loadingStatus = '';
  ApiExchange? _lastExchange;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false; // Track sending state
  bool _isCancelled = false; // Track cancellation

  bool _isRefreshDisabled = false; // Track refresh button disabled state

  // Concurrency Control
  Future<void> _apiLock = Future.value();
  int _busyCount = 0;

  final FocusNode _messageFocusNode = FocusNode();

  Future<T> _locked<T>(Future<T> Function() op) {
    setState(() => _busyCount++);
    final completer = Completer<T>();

    // Chain the operation to the tail of the lock
    final next = _apiLock.then((_) async {
      try {
        final result = await op();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    // Update the lock to point to the new tail
    _apiLock = next.then((_) {}).catchError((_) {});

    // Ensure busy count is decremented when this specific op finishes
    return completer.future.whenComplete(() {
      if (mounted) {
        setState(() => _busyCount--);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _messageFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          HardwareKeyboard.instance.isControlPressed) {
        if (_messageController.text.isNotEmpty) {
          _sendMessage(_messageController.text);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _session = widget.session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      switch (settings.refreshOnOpen) {
        case SessionRefreshPolicy.none:
          // Try to load from cache even if "refresh" is none?
          // Originally _fetchActivities defaults to check cache first.
          // Is "None" just "No Network"?
          // Assuming "None" means rely on passed session or cache only, do not fetch.
          // But _fetchActivities(force: false) basically does that if cache is fresh.
          // Let's call it with special handling, or just skip?
          // If we skip, we might show empty list.
          // Let's assume "None" means "No Auto Refresh", but still load initial data (cache).
          // But the setting is "Refresh on Open".
          // If we interpret strictly:
          _fetchActivities(
            force: false,
            shallow: true,
          ); // Normal load (uses cache)
          break;
        case SessionRefreshPolicy.shallow:
          _fetchActivities(force: false, shallow: true);
          break;
        case SessionRefreshPolicy.full:
          _fetchActivities(force: true, shallow: false);
          break;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshDisabled) return;

    setState(() {
      _isRefreshDisabled = true;
    });

    try {
      final fetchFuture = _fetchActivities(force: true, shallow: true);
      final timeoutFuture = Future.delayed(const Duration(seconds: 2));

      await Future.any([fetchFuture, timeoutFuture]);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshDisabled = false;
        });
      }
    }
  }

  Future<void> _fetchActivities({
    bool force = false,
    bool shallow = true,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Add timeout to prevent indefinite hanging
      await Future.any([
        _performFetchActivities(force: force, shallow: shallow),
        Future.delayed(const Duration(seconds: 30)).then((_) {
          throw Exception(
            'Request timed out after 30 seconds. Please check your connection and try again.',
          );
        }),
      ]);
    } catch (e) {
      if (shallow && _activities.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Partial refresh failed ($e), retrying full refresh...",
              ),
            ),
          );
        }
        // Recurse with force=true (full)
        _fetchActivities(force: true, shallow: false);
        return;
      }
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

  Future<void> _performFetchActivities({
    bool force = false,
    bool shallow = true,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final client = auth.client;
    final token = auth.token;
    final cacheService = Provider.of<CacheService>(context, listen: false);

    // 1. Check cache first
    // Only use cache if not forced. Also if shallow is requested but we have no activities yet, we treat it as init load (use cache).
    if (!force && token != null) {
      final cachedDetails = await cacheService.loadSessionDetails(
        token,
        widget.session.id,
      );
      if (cachedDetails != null) {
        final listUpdateTimeStr = widget.session.updateTime;
        final cachedSnapshotStr = cachedDetails.sessionUpdateTimeSnapshot;

        bool useCache = false;

        if (cachedSnapshotStr != null) {
          if (listUpdateTimeStr == null) {
            // List has no info, but cache exists. Use cache.
            useCache = true;
          } else {
            try {
              final listDate = DateTime.parse(listUpdateTimeStr);
              final cachedDate = DateTime.parse(cachedSnapshotStr);

              // If local cache is equal to or newer than the list's info, use cache.
              // We only fetch if list says there's a newer update than what we have.
              if (!listDate.isAfter(cachedDate)) {
                useCache = true;
              }
            } catch (e) {
              // If parsing fails, default to fetch
              useCache = false;
            }
          }
        }

        if (useCache) {
          if (mounted) {
            setState(() {
              _activities = cachedDetails.activities;
              // Use the cached session as it might be newer than the one passed from the stale list
              _session = cachedDetails.session;
            });
          }
          return;
        }
      }
    }

    // 2. Fetch if cache not used
    Session? updatedSession;
    List<Activity> activities = [];

    await _locked(() async {
      try {
        updatedSession = await client.getSession(widget.session.name);
      } catch (e) {
        throw Exception('Failed to load session details: $e');
      }

      try {
        if (mounted) {
          setState(() {
            _loadingStatus = shallow
                ? 'Fetching latest activities...'
                : 'Fetching conversation history...';
          });
        }
        activities = await client.listActivities(
          widget.session.name,
          onDebug: (exchange) {
            _lastExchange = exchange;
          },
          onProgress: (count) {
            if (mounted) {
              setState(() {
                _loadingStatus =
                    'Loaded $count new activities...'; // "new" if shallow
              });
            }
          },
          shouldStop: (shallow && _activities.isNotEmpty)
              ? (act) => _activities.any((existing) => existing.id == act.id)
              : null,
        );
      } catch (e) {
        throw Exception('Failed to load conversation history: $e');
      }
    });

    if (mounted) {
      setState(() {
        if (activities.isNotEmpty) {
          // If we fetched new ones, merge.
          if (shallow && _activities.isNotEmpty) {
            final newIds = activities.map((a) => a.id).toSet();
            final oldUnique =
                _activities.where((a) => !newIds.contains(a.id)).toList();

            // Combine and Sort
            _activities = [...activities, ...oldUnique];
            // Sort by CreateTime Ascending (Oldest First) which is standard for Chat
            try {
              _activities.sort(
                (a, b) => DateTime.parse(
                  a.createTime,
                ).compareTo(DateTime.parse(b.createTime)),
              );
            } catch (_) {}
          } else {
            _activities = activities;
            try {
              _activities.sort(
                (a, b) => DateTime.parse(
                  a.createTime,
                ).compareTo(DateTime.parse(b.createTime)),
              );
            } catch (_) {}
          }
        }
        _session = updatedSession!;
        // Clear local activities as we now have server state
      });
    }

    // 3. Save to cache
    // 3. Save to cache
    if (token != null && updatedSession != null) {
      await cacheService.saveSessionDetails(token, updatedSession!, activities);

      if (mounted) {
        await Provider.of<SessionProvider>(
          context,
          listen: false,
        ).updateSession(updatedSession!, authToken: token);
      }
    }
  }

  Future<void> _sendMessage(String message) async {
    final queueProvider = Provider.of<MessageQueueProvider>(
      context,
      listen: false,
    );

    // Offline Case
    if (queueProvider.isOffline) {
      queueProvider.addMessage(_session.id, message, reason: 'offline');
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Message added to offline queue")),
        );
        setState(() {}); // Trigger rebuild
      }
      return;
    }

    // Attempting Online Send
    setState(() {
      _isSending = true;
      _isCancelled = false;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final client = auth.client;

      // Logically cancel (ignore result) if user cancels, but we can't truly cancel the future
      await _locked(() async {
        await client.sendMessage(_session.name, message);
      });

      if (_isCancelled) {
        // User cancelled, but it succeeded. Logic handled by potential earlier queueing if desired,
        // but here we just ignore success if we wanted to 'cancel'.
        // Given we don't 'un-send', we just proceed if not cancelled, or do nothing if cancelled.
      } else {
        if (mounted) {
          Provider.of<SessionProvider>(
            context,
            listen: false,
          ).addPendingMessage(_session.id, message, auth.token!);
        }
        _messageController.clear();

        if (mounted) {
          // Refresh based on settings
          final settings = Provider.of<SettingsProvider>(
            context,
            listen: false,
          );
          switch (settings.refreshOnMessage) {
            case SessionRefreshPolicy.none:
              break;
            case SessionRefreshPolicy.shallow:
              _fetchActivities(force: true, shallow: true);
              break;
            case SessionRefreshPolicy.full:
              _fetchActivities(force: true, shallow: false);
              break;
          }
        }
      }
    } catch (e) {
      if (_isCancelled) {
        return;
      }

      bool handled = false;
      // Check for RESOURCE_EXHAUSTED (429)
      if (e is JulesException && e.responseBody != null) {
        try {
          final body = jsonDecode(e.responseBody!);
          if (body is Map && body.containsKey('error')) {
            final error = body['error'];
            if (error is Map) {
              if (error['code'] == 429 ||
                  error['status'] == 'RESOURCE_EXHAUSTED') {
                if (mounted) {
                  // Scenario: User is watching. Restore text, don't queue.
                  _messageController.text = message;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "API Error: Resource Exhausted. Message restored to input.",
                      ),
                    ),
                  );
                } else {
                  // Scenario: User navigated away. Queue it.
                  queueProvider.addMessage(
                    _session.id,
                    message,
                    reason: 'resource_exhausted',
                  );
                }
                handled = true;
              } else if (error['code'] == 503 ||
                  error['status'] == 'UNAVAILABLE') {
                if (mounted) {
                  _messageController.text = message;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "API Error: Service Unavailable. Message restored to input.",
                      ),
                    ),
                  );
                } else {
                  queueProvider.addMessage(
                    _session.id,
                    message,
                    reason: 'service_unavailable',
                  );
                }
                handled = true;
              }
            }
          }
        } catch (_) {
          // Ignore parsing errors
        }
      }

      if (!handled) {
        if (!mounted) {
          // Queue if user navigated away
          queueProvider.addMessage(
            _session.id,
            message,
            reason: 'error_unmounted',
          );
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isCancelled = false;
        });
      }
    }
  }

  void _restoreDraft(QueuedMessage msg) {
    if (_messageController.text.isNotEmpty) {
      // Append? Or warn? Let's append with newline for now to be safe
      _messageController.text = "${_messageController.text}\n${msg.content}";
    } else {
      _messageController.text = msg.content;
    }
    // Remove from queue
    Provider.of<MessageQueueProvider>(
      context,
      listen: false,
    ).deleteMessage(msg.id);
  }

  Future<void> _approvePlan() async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await _locked(() async {
        await client.approvePlan(_session.name);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Plan Approved")));
      }
      _fetchActivities();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _refreshActivity(Activity activity) async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final updatedActivity = await _locked(() async {
        return await client.getActivity(activity.name);
      });

      if (!mounted) return;

      setState(() {
        final index = _activities.indexWhere((a) => a.id == activity.id);
        if (index != -1) {
          _activities[index] = updatedActivity;
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Activity refreshed")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to refresh activity: $e")),
        );
      }
    }
  }

  Future<void> _createNewSessionFromCurrent() async {
    final NewSessionResult? result = await showDialog<NewSessionResult>(
      context: context,
      builder: (context) => NewSessionDialog(initialSession: _session),
    );

    if (result == null || !mounted) return;

    _handleNewSessionResult(result);
  }

  Future<void> _handleNewSessionResult(NewSessionResult result) async {
    if (result.isDraft) {
      // Handle drafts
      final queueProvider = Provider.of<MessageQueueProvider>(
        context,
        listen: false,
      );
      for (final session in result.sessions) {
        queueProvider.addCreateSessionRequest(session, isDraft: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.sessions.length} draft(s) saved successfully',
          ),
        ),
      );
      return;
    }

    // Handle session creation
    final sessionsToCreate = result.sessions;
    if (sessionsToCreate.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Starting creation of ${sessionsToCreate.length} sessions...',
          ),
        ),
      );
    }

    for (final session in sessionsToCreate) {
      await _performCreate(session, sessionsToCreate.length > 1);
    }
  }

  Future<void> _performCreate(Session sessionToCreate, bool isBulk) async {
    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      await client.createSession(sessionToCreate);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session created successfully!')),
      );

      // Optionally, refresh the main list in the background
      final sessionProvider = Provider.of<SessionProvider>(
        context,
        listen: false,
      );
      final auth = Provider.of<AuthProvider>(context, listen: false);
      sessionProvider.fetchSessions(
        client,
        force: true,
        shallow: true,
        authToken: auth.token,
      );
    } catch (e) {
      if (!mounted) return;

      bool handled = false;
      if (e is JulesException && e.responseBody != null) {
        try {
          final body = jsonDecode(e.responseBody!);
          if (body is Map && body.containsKey('error')) {
            final error = body['error'];
            if (error is Map) {
              final status = error['status'];
              if (status == 'RESOURCE_EXHAUSTED' || status == 'UNAVAILABLE') {
                Provider.of<MessageQueueProvider>(
                  context,
                  listen: false,
                ).addCreateSessionRequest(
                  sessionToCreate,
                  reason: status.toLowerCase(),
                );
                if (!isBulk) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'API limit reached. Session creation queued.',
                      ),
                    ),
                  );
                }
                handled = true;
              }
            }
          }
        } catch (_) {}
      }

      if (!handled) {
        Provider.of<MessageQueueProvider>(
          context,
          listen: false,
        ).addCreateSessionRequest(sessionToCreate, reason: 'creation_failed');
        if (!isBulk) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Creating Session'),
              content: SelectableText(e.toString()),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDevMode = Provider.of<DevModeProvider>(context).isDevMode;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.token != null) {
            // Fire and forget
            Provider.of<SessionProvider>(
              context,
              listen: false,
            ).markAsRead(_session.id, auth.token!);
          }
          // Auto-save draft
          if (_messageController.text.trim().isNotEmpty) {
            Provider.of<MessageQueueProvider>(
              context,
              listen: false,
            ).saveDraft(_session.id, _messageController.text);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(
            _session.title ?? _session.name.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Session',
              onPressed: _createNewSessionFromCurrent,
            ),
            if (_session.outputs != null &&
                _session.outputs!.any((o) => o.pullRequest != null))
              IconButton(
                icon: const Icon(Icons.merge_type, color: Colors.purple),
                tooltip: 'Open Pull Request',
                onPressed: () {
                  final pr = _session.outputs!
                      .firstWhere((o) => o.pullRequest != null)
                      .pullRequest!;
                  launchUrl(Uri.parse(pr.url));
                },
              ),
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
            Consumer<MessageQueueProvider>(
              builder: (context, queueProvider, _) {
                if (queueProvider.isOffline) {
                  if (queueProvider.isConnecting) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.wifi_off),
                    tooltip: 'Go Online',
                    onPressed: () async {
                      final auth = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final online = await queueProvider.goOnline(auth.client);
                      if (!context.mounted) return;
                      if (online) {
                        _fetchActivities(force: true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Still offline")),
                        );
                      }
                    },
                  );
                }
                return IconButton(
                  icon: _isRefreshDisabled
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  // Disable/Gray out while "busy" (min 2s or until completion)
                  // Also blockout if any other network op is running
                  onPressed: (_isRefreshDisabled || _busyCount > 0)
                      ? null
                      : _handleRefresh,
                  tooltip: 'Refresh',
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'mark_unread_back') {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await Provider.of<SessionProvider>(
                    context,
                    listen: false,
                  ).markAsUnread(_session.id, auth.token!);
                  if (context.mounted) Navigator.pop(context);
                } else if (value == 'pr_back') {
                  final pr = _session.outputs!
                      .firstWhere((o) => o.pullRequest != null)
                      .pullRequest!;
                  launchUrl(Uri.parse(pr.url));
                  if (context.mounted) Navigator.pop(context);
                } else if (value == 'copy_pr_url') {
                  final pr = _session.outputs!
                      .firstWhere((o) => o.pullRequest != null)
                      .pullRequest!;
                  await Clipboard.setData(ClipboardData(text: pr.url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PR URL copied')),
                    );
                  }
                } else if (value == 'full_refresh') {
                  _fetchActivities(force: true, shallow: false);
                } else if (value == 'copy_id') {
                  await Clipboard.setData(ClipboardData(text: _session.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session ID copied')),
                    );
                  }
                } else if (value == 'open_browser') {
                  if (_session.url != null) {
                    launchUrl(Uri.parse(_session.url!));
                  }
                } else if (value == 'copy_jules_url') {
                  if (_session.url != null) {
                    await Clipboard.setData(ClipboardData(text: _session.url!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Jules URL copied')),
                      );
                    }
                  }
                } else if (value == 'approve_plan') {
                  _approvePlan();
                } else if (value == 'watch') {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await Provider.of<SessionProvider>(
                    context,
                    listen: false,
                  ).toggleWatch(_session.id, auth.token!);
                  setState(() {}); // Rebuild to update menu icon
                } else if (value == 'hide_back') {
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await Provider.of<SessionProvider>(
                    context,
                    listen: false,
                  ).toggleHidden(_session.id, auth.token!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (context) => [
                if (_session.outputs != null &&
                    _session.outputs!.any((o) => o.pullRequest != null))
                  const PopupMenuItem(
                    value: 'pr_back',
                    child: Row(
                      children: [
                        Icon(Icons.merge_type, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Open PR and Go Back'),
                      ],
                    ),
                  ),
                if (_session.outputs != null &&
                    _session.outputs!.any((o) => o.pullRequest != null))
                  const PopupMenuItem(
                    value: 'copy_pr_url',
                    child: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.blueGrey),
                        SizedBox(width: 8),
                        Text('Copy PR URL'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'hide_back',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off),
                      SizedBox(width: 8),
                      Text('Hide and go back'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'mark_unread_back',
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_unread, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Mark as Unread and Go Back'),
                    ],
                  ),
                ),

                const PopupMenuDivider(),
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.add_circle_outline),
                      SizedBox(width: 8),
                      Text('Resubmit as new session'),
                    ],
                  ),
                  onTap: () async {
                    await resubmitSession(context, _session,
                        hideOriginal: false);
                  },
                ),
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.visibility_off_outlined),
                      SizedBox(width: 8),
                      Text('Resubmit as new session and hide'),
                    ],
                  ),
                  onTap: () async {
                    final success = await resubmitSession(context, _session,
                        hideOriginal: true);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
                const PopupMenuDivider(),
                // Watch Toggle - we need to know current watch state.
                // We access it via SessionProvider -> items.
                // Note: This relies on cached items being up to date.
                if (Provider.of<SessionProvider>(
                  context,
                  listen: false,
                ).items.any(
                      (i) => i.data.id == _session.id && i.metadata.isWatched,
                    ))
                  const PopupMenuItem(
                    value: 'watch',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_off, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Unwatch'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'watch',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Watch'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'full_refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Full Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy_id',
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Copy Session ID'),
                    ],
                  ),
                ),
                if (_session.url != null)
                  const PopupMenuItem(
                    value: 'open_browser',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_browser, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Open in Browser'),
                      ],
                    ),
                  ),
                if (_session.url != null)
                  const PopupMenuItem(
                    value: 'copy_jules_url',
                    child: Row(
                      children: [
                        Icon(Icons.copy, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Copy Jules Link'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'approve_plan',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Force Approve Plan'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.label, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Manage Tags'),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          TagManagementDialog(session: _session),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isSending)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),

            // Permanent Header
            _buildHeader(context),

            // Scrollable Activity List
            if (_isLoading && _activities.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _loadingStatus,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildActivityList(isDevMode)),

            // Permanent Input Footer
            _buildInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(bool isDevMode) {
    if (_isLoading && _activities.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              SelectableText(_error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: _fetchActivities,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    bool hasPr = _session.outputs != null &&
        _session.outputs!.any((o) => o.pullRequest != null);

    // Group Activities
    final List<ActivityListItem> groupedItems = [];
    ActivityGroupWrapper? currentGroup;

    // Merge queued messages
    final queueProvider = Provider.of<MessageQueueProvider>(context);
    final queuedMessages =
        queueProvider.queue.where((m) => m.sessionId == _session.id).toList();

    final queuedActivities = queuedMessages.map(
      (m) => Activity(
        name: "queued/${m.id}",
        id: "queued-${m.id}",
        createTime: m.createdAt.toIso8601String(),
        userMessaged: UserMessaged(userMessage: m.content),
        description: "Queued Message",
        unmappedProps: {
          'isQueued': true,
          'queueReason': m.queueReason,
          'processingErrors': m.processingErrors,
        },
      ),
    );

    // Merge pending messages (Optimistic updates)
    final sessionProvider = Provider.of<SessionProvider>(context);
    final sessionItem = sessionProvider.items.firstWhere(
      (i) => i.data.id == _session.id,
      orElse: () => CachedItem(
        _session,
        CacheMetadata(firstSeen: DateTime.now(), lastRetrieved: DateTime.now()),
      ),
    );
    final pendingMessages = sessionItem.metadata.pendingMessages;

    // If session is FAILED, pending messages are effectively failed/queued
    final isSessionFailed = _session.state == SessionState.FAILED;

    final pendingActivities = pendingMessages.map((m) {
      if (isSessionFailed) {
        return Activity(
          name: "pending/${m.id}",
          id: "pending-${m.id}",
          createTime: m.timestamp.toIso8601String(),
          userMessaged: UserMessaged(userMessage: m.content),
          description: "Sending Failed",
          unmappedProps: {
            'isQueued': true,
            'queueReason': 'Session is in FAILED state',
            'pendingId': m.id,
          },
        );
      }
      return Activity(
        name: "pending/${m.id}",
        id: "pending-${m.id}",
        createTime: m.timestamp.toIso8601String(),
        userMessaged: UserMessaged(userMessage: m.content),
        description: "Sending...",
        unmappedProps: {
          'isPending': true,
          'hasMismatch': m.hasMismatch,
          'pendingId': m.id,
        },
      );
    });

    final allActivities = [
      ..._activities,
      ...queuedActivities,
      ...pendingActivities,
    ];
    allActivities.sort(
      (a, b) =>
          DateTime.parse(a.createTime).compareTo(DateTime.parse(b.createTime)),
    );

    for (var activity in allActivities) {
      final info = ActivityDisplayInfo.fromActivity(activity);

      if (currentGroup != null) {
        if (currentGroup.info.title == info.title &&
            currentGroup.info.summary == info.summary &&
            currentGroup.info.icon == info.icon) {
          currentGroup.activities.add(activity);
          continue;
        } else {
          groupedItems.add(currentGroup);
          currentGroup = null;
        }
      }

      currentGroup = ActivityGroupWrapper([activity], info);
    }
    if (currentGroup != null) {
      groupedItems.add(currentGroup);
    }

    // Flatten small groups
    final List<ActivityListItem> finalItems = [];
    for (var item in groupedItems) {
      if (item is ActivityGroupWrapper && item.activities.length < 3) {
        for (var a in item.activities) {
          finalItems.add(ActivityItemWrapper(a));
        }
      } else {
        finalItems.add(item);
      }
    }

    return ListView.builder(
      reverse: true, // Start at bottom, visual index 0 is bottom
      itemCount:
          finalItems.length + (hasPr ? 2 : 0) + 1, // +1 for Last Updated Status
      itemBuilder: (context, index) {
        if (index == 0) {
          // Visual Bottom: Last Updated Status
          if (_session.updateTime != null) {
            final updateTime = DateTime.parse(_session.updateTime!).toLocal();
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _isLoading
                      ? "Last updated: ${DateFormat.Hms().format(updateTime)} (${timeAgo(updateTime)}) - $_loadingStatus"
                      : "Last updated: ${DateFormat.Hms().format(updateTime)} (${timeAgo(updateTime)})",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            DateTime.now().difference(updateTime).inMinutes > 15
                                ? Colors.orange
                                : Colors.grey,
                      ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        // Adjust index for status item
        final int adjIndex = index - 1;

        if (hasPr) {
          if (adjIndex == 0 || adjIndex == finalItems.length + 1) {
            return _buildPrNotice(context);
          }
        }

        final int listIndex = hasPr ? adjIndex - 1 : adjIndex;

        if (listIndex < 0 || listIndex >= finalItems.length) {
          return const SizedBox.shrink();
        }

        final itemWrapper = finalItems[finalItems.length - 1 - listIndex];

        // Date Header Logic
        Widget? dateHeader;
        DateTime? itemTime;
        if (itemWrapper is ActivityItemWrapper) {
          itemTime = DateTime.parse(itemWrapper.activity.createTime).toLocal();
        } else if (itemWrapper is ActivityGroupWrapper &&
            itemWrapper.activities.isNotEmpty) {
          itemTime = DateTime.parse(
            itemWrapper.activities.first.createTime,
          ).toLocal();
        }

        if (itemTime != null) {
          bool showHeader = false;
          final int olderIndex = listIndex + 1;
          if (olderIndex < finalItems.length) {
            final olderWrapper = finalItems[finalItems.length - 1 - olderIndex];
            DateTime? olderTime;
            if (olderWrapper is ActivityItemWrapper) {
              olderTime = DateTime.parse(
                olderWrapper.activity.createTime,
              ).toLocal();
            } else if (olderWrapper is ActivityGroupWrapper &&
                olderWrapper.activities.isNotEmpty) {
              olderTime = DateTime.parse(
                olderWrapper.activities.first.createTime,
              ).toLocal();
            }

            if (olderTime != null) {
              if (olderTime.year != itemTime.year ||
                  olderTime.month != itemTime.month ||
                  olderTime.day != itemTime.day) {
                showHeader = true;
              }
            }
          } else {
            // Oldest item
            showHeader = true;
          }

          if (showHeader) {
            dateHeader = Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(itemTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        Widget content;
        if (itemWrapper is ActivityGroupWrapper) {
          content = _buildGroupItem(itemWrapper, isDevMode);
        } else if (itemWrapper is ActivityItemWrapper) {
          final activity = itemWrapper.activity;

          // If it's a local activity (pending/queued), "refresh" should just check sync status (full fetch)
          // instead of trying to hit the API for a non-existent ID.
          final isLocal = activity.id.startsWith('pending-') ||
              activity.id.startsWith('queued-');

          final item = ActivityItem(
            activity: activity,
            onRefresh: isLocal
                ? () => _fetchActivities(force: true, shallow: true)
                : () => _refreshActivity(activity),
          );

          if (isDevMode) {
            content = GestureDetector(
              onLongPress: () => _showContextMenu(context, activity: activity),
              onSecondaryTap: () =>
                  _showContextMenu(context, activity: activity),
              child: item,
            );
          } else {
            final isQueued = activity.unmappedProps['isQueued'] == true;
            if (isQueued) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: Stack(
                      children: [
                        item,
                        const Positioned(
                          right: 8,
                          top: 8,
                          child: Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activity.unmappedProps.containsKey('pendingId'))
                    Container(
                      margin: const EdgeInsets.only(
                        top: 4,
                        right: 12,
                        bottom: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => ModelViewer(
                                  data: activity.toJson(),
                                  title: 'Activity Data',
                                ),
                              );
                            },
                            child: const Text("View Data"),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () {
                              final auth = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              Provider.of<SessionProvider>(
                                context,
                                listen: false,
                              ).removePendingMessage(
                                _session.id,
                                activity.unmappedProps['pendingId'],
                                auth.token!,
                              );
                            },
                            child: const Text("Dismiss"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: () {
                              final auth = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final pId = activity.unmappedProps['pendingId'];
                              final content =
                                  activity.userMessaged!.userMessage;
                              // Remove old one
                              Provider.of<SessionProvider>(
                                context,
                                listen: false,
                              ).removePendingMessage(
                                _session.id,
                                pId,
                                auth.token!,
                              );
                              // Resend (which adds new pending)
                              _sendMessage(content);
                            },
                            child: const Text("Resend"),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            } else {
              final isLocal = activity.unmappedProps['isLocal'] == true;
              if (isLocal) {
                content = Stack(
                  children: [
                    Opacity(
                      opacity: 0.8,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.blue,
                            ),
                            onPressed: (_isRefreshDisabled || _busyCount > 0)
                                ? null
                                : _handleRefresh,
                            tooltip: "Refresh (Client Only)",
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                content = item;
              }
            }
          }
        } else {
          content = const SizedBox.shrink();
        }

        if (dateHeader != null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [dateHeader, content],
          );
        }
        return content;
      },
    );
  }

  Widget _buildGroupItem(ActivityGroupWrapper group, bool isDevMode) {
    DateTime? start;
    DateTime? end;
    if (group.activities.isNotEmpty) {
      try {
        start = DateTime.parse(group.activities.first.createTime);
      } catch (_) {}
      try {
        end = DateTime.parse(group.activities.last.createTime);
      } catch (_) {}
    }

    final count = group.activities.length;
    final title = group.info.title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: ExpansionTile(
          shape: const Border(),
          title: Row(
            children: [
              Icon(group.info.icon, color: group.info.iconColor, size: 20),
              const SizedBox(width: 12),
              Text(
                "$count x $title",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (start != null && end != null)
                Text(
                  "${DateFormat.Hms().format(start.toLocal())} - ${DateFormat.Hms().format(end.toLocal())}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          children: group.activities.map((a) {
            final item = ActivityItem(
              activity: a,
              onRefresh: () => _refreshActivity(a),
            );
            if (isDevMode) {
              return GestureDetector(
                onLongPress: () => _showContextMenu(context, activity: a),
                onSecondaryTap: () => _showContextMenu(context, activity: a),
                child: item,
              );
            }
            if (a.unmappedProps['hasMismatch'] == true) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  item,
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 12, bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Message not synced",
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "This message doesn't appear in the server history yet.",
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () {
                                final auth = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                Provider.of<SessionProvider>(
                                  context,
                                  listen: false,
                                ).removePendingMessage(
                                  _session.id,
                                  a.unmappedProps['pendingId'],
                                  auth.token!,
                                );
                              },
                              child: const Text("Dismiss"),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () {
                                final auth = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                final pId = a.unmappedProps['pendingId'];
                                final content = a.userMessaged!.userMessage;
                                // Remove old one
                                Provider.of<SessionProvider>(
                                  context,
                                  listen: false,
                                ).removePendingMessage(
                                  _session.id,
                                  pId,
                                  auth.token!,
                                );
                                // Resend (which adds new pending)
                                _sendMessage(content);
                              },
                              child: const Text("Resend"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return item;
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPrNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: Colors.purple.shade50,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.purple.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text(
              "Pull Request Available",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            leading: const Icon(Icons.merge_type, color: Colors.purple),
            children: [
              for (final output in _session.outputs!.where(
                (o) => o.pullRequest != null,
              ))
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        output.pullRequest!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        output.pullRequest!.description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text("Open Pull Request"),
                          onPressed: () =>
                              launchUrl(Uri.parse(output.pullRequest!.url)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start with Pills (State, Date, Automation, Approval, Source, Branch)
                    // Start with Pills (State, Date, Automation, Approval, PR Status, Source, Branch)
                    SessionMetaPills(session: _session),
                    const SizedBox(height: 12),
                    Text(
                      "Prompt:",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isPromptExpanded = !_isPromptExpanded;
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: _isPromptExpanded
                                    ? MediaQuery.sizeOf(context).height * 0.4
                                    : 60,
                              ),
                              width: double.infinity,
                              clipBehavior: _isPromptExpanded
                                  ? Clip.hardEdge
                                  : Clip.hardEdge,
                              decoration: const BoxDecoration(),
                              foregroundDecoration: _isPromptExpanded
                                  ? null
                                  : BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.8),
                                        ],
                                        stops: const [0.5, 1.0],
                                      ),
                                    ),
                              child: SingleChildScrollView(
                                child: MarkdownBody(data: _session.prompt),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              _isPromptExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final hasText = _messageController.text.isNotEmpty;
    final canApprove = _session.state == SessionState.AWAITING_PLAN_APPROVAL &&
        (_session.requirePlanApproval ?? true);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Draft / Queue Indicator
            Consumer<MessageQueueProvider>(
              builder: (context, queueProvider, child) {
                final drafts = queueProvider.getDrafts(_session.id);
                if (drafts.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                    child: Badge(
                      label: Text("${drafts.length}"),
                      child: PopupMenuButton<QueuedMessage>(
                        icon: const Icon(
                          Icons.drafts_outlined,
                          color: Colors.orange,
                        ),
                        tooltip: "Manage Drafts",
                        onSelected: (draft) {
                          // Handle selection in menu builder but we need action
                        },
                        itemBuilder: (context) {
                          return drafts.map((d) {
                            return PopupMenuItem(
                              value: d,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      d.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.restore, size: 20),
                                    onPressed: () {
                                      _restoreDraft(d);
                                      Navigator.pop(context);
                                    },
                                    tooltip: "Restore",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      queueProvider.deleteMessage(d.id);
                                      Navigator.pop(context); // Close menu
                                    },
                                    tooltip: "Delete",
                                  ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: const InputDecoration(
                  hintText: "Send message... (Ctrl+Enter to send)",
                ),
                minLines: 1,
                enabled: !_isSending, // Disable input while sending
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: _isSending ? null : (text) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            if (hasText && !_isSending)
              IconButton(
                icon: const Icon(Icons.save_as, color: Colors.grey),
                tooltip: "Save as Draft",
                onPressed: () {
                  final content = _messageController.text;
                  Provider.of<MessageQueueProvider>(
                    context,
                    listen: false,
                  ).saveDraft(_session.id, content);
                  _messageController.clear();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Draft saved")));
                },
              ),
            if (hasText || _isSending)
              IconButton(
                icon: const Icon(Icons.send),
                // Disable button (gray out) when sending
                onPressed: _isSending
                    ? null
                    : () => _sendMessage(_messageController.text),
                tooltip: _isSending ? 'Sending...' : 'Send Message',
              )
            else if (canApprove)
              ElevatedButton(
                onPressed: _approvePlan,
                child: const Text("Approve Plan"),
              )
            else
              const IconButton(
                icon: Icon(Icons.send),
                onPressed: null,
                tooltip: 'Send Message (Empty)',
              ),
          ],
        ),
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
