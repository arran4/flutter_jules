import 'package:flutter/material.dart';

import 'cache_service.dart';
import 'jules_client.dart';
import 'exceptions.dart';
import '../models.dart';

class MessageQueueProvider extends ChangeNotifier {
  List<QueuedMessage> _queue = [];
  bool _isOffline = false;
  bool _isConnecting = false;
  CacheService? _cacheService;
  String? _authToken;

  List<QueuedMessage> get queue => _queue;
  bool get isOffline => _isOffline;
  bool get isConnecting => _isConnecting;

  void setCacheService(CacheService service, String? token) {
    _cacheService = service;
    _authToken = token;
    if (token != null) {
      _loadQueue();
    }
  }

  // Explicitly set offline mode (e.g. on startup or if user wants to)
  // Or automatically if API calls fail
  void setOffline(bool value) {
    if (_isOffline != value) {
      _isOffline = value;
      notifyListeners();
    }
  }

  Future<void> _loadQueue() async {
    if (_cacheService != null && _authToken != null) {
      _queue = await _cacheService!.loadMessageQueue(_authToken!);
      await _migrateQueue(); // Temporary migration
      notifyListeners();
    }
  }

  Future<void> _migrateQueue() async {
    bool changed = false;
    for (var i = 0; i < _queue.length; i++) {
        final m = _queue[i];
        // Fix 1: 'new_session' messages that are not tagged as sessionCreation
        // This was a previous bug where they were stored as simple messages
        if (m.sessionId == 'new_session' && m.type == QueuedMessageType.message) {
             // Convert to sessionCreation and Draft
             // We need to ensure metadata exists. If not, try to recover from content?
             // But content for new session IS the prompt.
             Map<String, dynamic> metadata = m.metadata ?? {};
             if (metadata.isEmpty) {
                 // Create minimal session metadata
                 metadata = Session(
                     id: '',
                     name: '',
                     prompt: m.content,
                     sourceContext: SourceContext(source: ''),
                 ).toJson();
             }

             _queue[i] = QueuedMessage(
                 id: m.id,
                 sessionId: m.sessionId,
                 content: m.content,
                 createdAt: m.createdAt,
                 type: QueuedMessageType.sessionCreation, // Fixed type
                 metadata: metadata,
                 queueReason: m.queueReason ?? 'migrated_legacy_item',
                 isDraft: true, // Force to draft for review
                 processingErrors: m.processingErrors,
             );
             changed = true;
        }
    }
    
    if (changed) {
        await _saveQueue();
        debugPrint("Message Queue migrated successfully.");
    }
  }

  Future<void> _saveQueue() async {
    if (_cacheService != null && _authToken != null) {
      await _cacheService!.saveMessageQueue(_authToken!, _queue);
    }
  }

  String addMessage(String sessionId, String content,
      {String? reason, bool isDraft = false}) {
    final message = QueuedMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: sessionId,
      content: content,
      createdAt: DateTime.now(),
      queueReason: reason,
      isDraft: isDraft,
    );
    _queue.add(message);
    _saveQueue();
    notifyListeners();
    return message.id;
  }

  String addCreateSessionRequest(Session session,
      {String? reason, bool isDraft = false}) {
    final message = QueuedMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sessionId: 'new_session', // Placeholder
      content: session.prompt,
      createdAt: DateTime.now(),
      type: QueuedMessageType.sessionCreation,
      metadata: session.toJson(),
      queueReason: reason,
      isDraft: isDraft,
    );
    _queue.add(message);
    _saveQueue();
    notifyListeners();
    return message.id;
  }

  void updateMessage(String id, String newContent) {
    final index = _queue.indexWhere((m) => m.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(content: newContent);
      _saveQueue();
      notifyListeners();
    }
  }

  void updateCreateSessionRequest(String id, Session session,
      {bool? isDraft, String? reason}) {
    final index = _queue.indexWhere((m) => m.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(
        content: session.prompt,
        metadata: session.toJson(),
        isDraft: isDraft,
        queueReason: reason,
      );
      _saveQueue();
      notifyListeners();
    }
  }

  void deleteMessage(String id) {
    _queue.removeWhere((m) => m.id == id);
    _saveQueue();
    notifyListeners();
  }

  void saveDraft(String sessionId, String content) {
    // Check if draft already exists? User might want multiple.
    // Assuming adding new draft always for now, or updating if ID known.
    // For simplicity, just add.
    addMessage(sessionId, content, isDraft: true, reason: 'User saved as draft');
  }

  List<QueuedMessage> getDrafts(String sessionId) {
    return _queue
        .where((m) => m.sessionId == sessionId && m.isDraft)
        .toList();
  }

  // Returns true if connection successful
  Future<bool> goOnline(JulesClient client) async {
    if (_isConnecting) return false;
    _isConnecting = true;
    notifyListeners();
    try {
      // Test endpoint with a lightweight call
      await client.listSessions(pageSize: 1);
      _isOffline = false;
      return true;
    } catch (e) {
      // Still offline
      // print("Go Online check failed: $e");
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> sendQueue(JulesClient client,
      {Function(String)? onMessageSent,
      Function(String, Object)? onError}) async {
    if (_isOffline) return;

    List<QueuedMessage> remaining =
        List.from(_queue.where((m) => !m.isDraft)); // Skip drafts
    List<QueuedMessage> toRemove = [];

    // Sort by creation time to send in order
    remaining.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final msg in remaining) {
      try {
        if (msg.type == QueuedMessageType.sessionCreation) {
          if (msg.metadata != null) {
            await client.createSession(Session.fromJson(msg.metadata!));
          }
        } else {
          await client.sendMessage(msg.sessionId, msg.content);
        }
        toRemove.add(msg);
        if (onMessageSent != null) onMessageSent(msg.id);
      } catch (e) {
        bool recovered = false;
        if (e is JulesException && e.statusCode == 404) {
          if (msg.sessionId == 'new_session') {
            // Attempt recovery: The message was likely a session creation request
            // that lost its type or was mishandled.
            try {
              Session sessionToCreate;
              if (msg.metadata != null) {
                sessionToCreate = Session.fromJson(msg.metadata!);
              } else {
                // Fallback: Create minimal session from content
                sessionToCreate = Session(
                  id: '',
                  name: '',
                  prompt: msg.content,
                  sourceContext: SourceContext(source: ''),
                );
              }
              await client.createSession(sessionToCreate);
              recovered = true;
              toRemove.add(msg);
              if (onMessageSent != null) onMessageSent(msg.id);
            } catch (_) {
              // Recovery failed, fall through to normal error handling
            }
          }
        }

        if (recovered) {
          continue;
        }

        if (onError != null) onError(msg.id, e);

        // Record error on the message
        final index = _queue.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          final currentErrors =
              List<String>.from(_queue[index].processingErrors);
          currentErrors.add(e.toString());
          _queue[index] =
              _queue[index].copyWith(processingErrors: currentErrors);
          await _saveQueue();
          notifyListeners();
        }

        // Stop on first error? Or continue? Usually stop to preserve order if dependent.
        // For now, let's stop on error to be safe.
        break;
      }
    }

    _queue.removeWhere((m) => toRemove.contains(m));
    await _saveQueue();
    notifyListeners();
  }
}
