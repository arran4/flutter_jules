import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bulk_action.dart';
import '../models/session.dart';
import '../models/enums.dart';
import 'session_provider.dart';
import 'jules_client.dart';
import 'auth_provider.dart';
import 'github_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BulkActionExecutor extends ChangeNotifier {
  final SessionProvider sessionProvider;
  final JulesClient julesClient;
  final AuthProvider authProvider;
  final GithubProvider githubProvider;

  BulkJobConfig? _config;
  List<Session> _queue = [];
  final List<String> _pausedSessionIds = [];
  List<Session> _completed = [];
  List<BulkLogEntry> _logs = [];
  BulkJobStatus _status = BulkJobStatus.pending;
  int _currentParallelCount = 0;
  Timer? _waitTimer;
  int _waitBetweenSecondsOverride = -1;

  // Stats
  int _totalToProcess = 0;
  DateTime? _startTime;

  BulkActionExecutor({
    required this.sessionProvider,
    required this.julesClient,
    required this.authProvider,
    required this.githubProvider,
  });

  BulkJobConfig? get config => _config;
  List<Session> get queue => _queue;
  List<String> get pausedSessionIds => _pausedSessionIds;
  List<Session> get completed => _completed;
  List<BulkLogEntry> get logs => _logs;
  BulkJobStatus get status => _status;
  int get totalToProcess => _totalToProcess;
  DateTime? get startTime => _startTime;

  int get waitBetweenSeconds => _waitBetweenSecondsOverride != -1
      ? _waitBetweenSecondsOverride
      : (_config?.waitBetween.inSeconds ?? 2);

  set waitBetweenSeconds(int value) {
    _waitBetweenSecondsOverride = value;
    notifyListeners();
  }

  String get estimatedTimeRemaining {
    if (_status == BulkJobStatus.completed) return "Done";
    if (_status == BulkJobStatus.canceled) return "Canceled";
    if (_status == BulkJobStatus.paused) return "Paused";
    if (_status != BulkJobStatus.running || _completed.isEmpty) {
      return "Calculating...";
    }

    final elapsed = DateTime.now().difference(_startTime!);
    final msPerSession = elapsed.inMilliseconds / _completed.length;
    final remainingCount = _queue.length - _pausedSessionIds.length;
    final remainingMs = msPerSession * remainingCount;

    if (remainingMs < 0) return "0s";

    final duration = Duration(milliseconds: remainingMs.toInt());
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    }
    if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${duration.inSeconds % 60}s";
    }
    return "${duration.inSeconds}s";
  }

  void startJob(BulkJobConfig config, List<Session> targets) {
    _config = config;
    _queue = List.from(targets);
    _completed = [];
    _logs = [];
    _totalToProcess = targets.length;
    _status = BulkJobStatus.running;
    _startTime = DateTime.now();
    _currentParallelCount = 0;

    _addLog("Starting bulk job with ${_queue.length} sessions.", false);
    _processNext();
    notifyListeners();
  }

  void pauseJob() {
    if (_status == BulkJobStatus.running) {
      _status = BulkJobStatus.paused;
      _waitTimer?.cancel();
      _addLog("Job paused.", false);
      notifyListeners();
    }
  }

  void resumeJob() {
    if (_status == BulkJobStatus.paused) {
      _status = BulkJobStatus.running;
      _addLog("Job resumed.", false);
      _processNext();
      notifyListeners();
    }
  }

  void cancelJob() {
    _status = BulkJobStatus.canceled;
    _waitTimer?.cancel();
    _addLog("Job canceled by user.", false);
    notifyListeners();
  }

  void removeFromQueue(String sessionId) {
    _queue.removeWhere((s) => s.id == sessionId);
    _pausedSessionIds.remove(sessionId);
    notifyListeners();
  }

  void togglePauseSession(String sessionId) {
    if (_pausedSessionIds.contains(sessionId)) {
      _pausedSessionIds.remove(sessionId);
    } else {
      _pausedSessionIds.add(sessionId);
    }
    notifyListeners();
  }

  void _addLog(String message, bool isError, [String? sessionId]) {
    _logs.insert(
      0,
      BulkLogEntry(
        message: message,
        isError: isError,
        sessionId: sessionId,
        timestamp: DateTime.now(),
      ),
    );
    if (_logs.length > 500) _logs.removeLast();
    notifyListeners();
  }

  Future<void> _processNext() async {
    if (_status != BulkJobStatus.running) return;
    if (_queue.isEmpty && _currentParallelCount == 0) {
      _status = BulkJobStatus.completed;
      _addLog("Bulk job completed successfully.", false);
      notifyListeners();
      return;
    }

    while (_currentParallelCount < (_config?.parallelQueries ?? 1) &&
        _queue.any((s) => !_pausedSessionIds.contains(s.id)) &&
        _status == BulkJobStatus.running) {
      final sessionIndex = _queue.indexWhere(
        (s) => !_pausedSessionIds.contains(s.id),
      );
      if (sessionIndex == -1) break;

      final session = _queue.removeAt(sessionIndex);
      _currentParallelCount++;
      notifyListeners();

      _runActionsForSession(session).then((_) {
        _currentParallelCount--;
        _completed.add(session);

        if (_status == BulkJobStatus.running) {
          final effectiveWait = waitBetweenSeconds;
          if (effectiveWait > 0 &&
              _queue.any((s) => !_pausedSessionIds.contains(s.id))) {
            _waitTimer = Timer(Duration(seconds: effectiveWait), () {
              _processNext();
            });
          } else {
            _processNext();
          }
        }
        notifyListeners();
      });
    }
  }

  Future<void> _runActionsForSession(Session session) async {
    final sessionTitle = session.title ?? session.name;
    _addLog(
      "Starting to process session: \"$sessionTitle\"",
      false,
      session.id,
    );

    final authToken = authProvider.token;
    int stepNumber = 0;

    for (var step in _config!.actions) {
      stepNumber++;
      final stepName = step.type.displayName;

      if (_status != BulkJobStatus.running && _status != BulkJobStatus.paused) {
        _addLog(
          "Job is no longer running. Stopping further actions for this session.",
          true,
          session.id,
        );
        break;
      }

      try {
        await _executeStep(session, step, authToken);
        _addLog(
          "Successfully executed step $stepNumber/${_config!.actions.length}: $stepName for session \"$sessionTitle\"",
          false,
          session.id,
        );
      } catch (e) {
        _addLog(
          "Error executing step $stepNumber/${_config!.actions.length} ($stepName) on session \"$sessionTitle\": $e",
          true,
          session.id,
        );

        if (_config!.stopOnError) {
          _addLog(
            "Configuration is set to stop on first error. Canceling the entire job.",
            true,
          );
          cancelJob();
          return;
        }

        _addLog(
          "Aborting remaining actions for this session due to the error.",
          true,
          session.id,
        );
        break;
      }
    }
    _addLog(
      "Finished processing all actions for session: \"$sessionTitle\"",
      false,
      session.id,
    );
  }

  Future<void> _executeStep(
    Session session,
    BulkActionStep step,
    String? authToken,
  ) async {
    final sessionTitle = session.title ?? session.name;
    switch (step.type) {
      case BulkActionType.openPrInBrowser:
        final url = _getPrUrl(session);
        if (url != null) {
          _addLog("Opening PR URL in browser: $url", false, session.id);
          await launchUrl(Uri.parse(url));
        } else {
          throw Exception("No PR URL was found for session \"$sessionTitle\"");
        }
        break;
      case BulkActionType.markAsRead:
        if (authToken != null) {
          await sessionProvider.markAsRead(session.id, authToken);
          _addLog("Marked session as read.", false, session.id);
        }
        break;
      case BulkActionType.markAsUnread:
        if (authToken != null) {
          await sessionProvider.markAsUnread(session.id, authToken);
          _addLog("Marked session as unread.", false, session.id);
        }
        break;
      case BulkActionType.hide:
        if (authToken != null) {
          await sessionProvider.toggleHidden(session.id, authToken);
          _addLog("Toggled visibility to hidden.", false, session.id);
        }
        break;
      case BulkActionType.unhide:
        if (authToken != null) {
          await sessionProvider.toggleHidden(session.id, authToken);
          _addLog("Toggled visibility to unhidden.", false, session.id);
        }
        break;
      case BulkActionType.refreshSession:
        await sessionProvider.refreshSession(
          julesClient,
          session.name,
          authToken: authToken,
        );
        _addLog(
          "Performed a shallow refresh of the session.",
          false,
          session.id,
        );
        break;
      case BulkActionType.deepRefresh:
        await sessionProvider.refreshSession(
          julesClient,
          session.name,
          authToken: authToken,
        );
        _addLog(
          "Performed a deep refresh (including activities).",
          false,
          session.id,
        );
        break;
      case BulkActionType.watchSession:
        if (authToken != null) {
          final item = sessionProvider.items.firstWhere(
            (i) => i.data.id == session.id,
            orElse: () =>
                throw Exception("Could not find session in local cache."),
          );
          if (!item.metadata.isWatched) {
            await sessionProvider.toggleWatch(session.id, authToken);
            _addLog("Enabled watching for this session.", false, session.id);
          } else {
            _addLog(
              "Session was already being watched. No action taken.",
              false,
              session.id,
            );
          }
        }
        break;
      case BulkActionType.unwatchSession:
        if (authToken != null) {
          final item = sessionProvider.items.firstWhere(
            (i) => i.data.id == session.id,
            orElse: () =>
                throw Exception("Could not find session in local cache."),
          );
          if (item.metadata.isWatched) {
            await sessionProvider.toggleWatch(session.id, authToken);
            _addLog("Disabled watching for this session.", false, session.id);
          } else {
            _addLog(
              "Session was not being watched. No action taken.",
              false,
              session.id,
            );
          }
        }
        break;
      case BulkActionType.openJulesLink:
        final url = "https://jules.corp.google.com/session/${session.id}";
        _addLog("Opening session in Jules UI: $url", false, session.id);
        await launchUrl(Uri.parse(url));
        break;
      case BulkActionType.quickReply:
        final message = step.message;
        if (message == null || message.isEmpty) {
          throw Exception("A message is required for a quick reply.");
        }
        _addLog("Sending quick reply: \"$message\"", false, session.id);
        await julesClient.sendMessage(session.name, message);
        if (authToken != null) {
          await sessionProvider.addPendingMessage(
            session.id,
            message,
            authToken,
          );
        }
        break;
      case BulkActionType.viewSourceRepo:
        final url = _getSourceRepoUrl(session);
        if (url != null) {
          _addLog(
            "Opening source repository in browser: $url",
            false,
            session.id,
          );
          await launchUrl(Uri.parse(url));
        } else {
          throw Exception(
            "No source repository URL was found for session \"$sessionTitle\"",
          );
        }
        break;
      case BulkActionType.forceRefreshPrStatus:
        if (authToken != null) {
          _addLog("Forcing a refresh of the PR status.", false, session.id);
          await sessionProvider.refreshGitStatus(session.id, authToken);
        }
        break;
      case BulkActionType.forceApprovePlan:
        _addLog("Forcing approval of the current plan.", false, session.id);
        await julesClient.approvePlan(session.name);
        break;
      case BulkActionType.duplicateSession:
        final newSession = session.copyWith(
          id: '',
          name: '',
          createTime: null,
          updateTime: null,
          state: SessionState.STATE_UNSPECIFIED,
        );
        _addLog(
          "Creating a new session by duplicating this one.",
          false,
          session.id,
        );
        await julesClient.createSession(newSession);
        break;
      case BulkActionType.sleep:
        final seconds = int.tryParse(step.message ?? '0') ?? 0;
        if (seconds > 0) {
          _addLog("Sleeping for $seconds seconds...", false, session.id);
          await Future.delayed(Duration(seconds: seconds));
          _addLog("Finished sleeping.", false, session.id);
        }
        break;
    }
  }

  String? _getPrUrl(Session session) {
    if (session.outputs != null) {
      for (var o in session.outputs!) {
        if (o.pullRequest != null) return o.pullRequest!.url;
      }
    }
    return null;
  }

  String? _getSourceRepoUrl(Session session) {
    if (session.outputs != null) {
      for (var o in session.outputs!) {
        if (o.pullRequest != null) {
          final uri = Uri.parse(o.pullRequest!.url);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length >= 2) {
            return "https://github.com/${pathSegments[0]}/${pathSegments[1]}";
          }
        }
      }
    }
    return null;
  }
}
