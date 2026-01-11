import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'cache_service.dart';
import 'jules_client.dart';

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
      var msg = _queue[i];

      // Fix 1: Legacy new_session message type
      if (msg.sessionId == 'new_session' &&
          msg.type != QueuedMessageType.sessionCreation) {
        debugPrint(
          "Migrating legacy message ${msg.id} to sessionCreation type",
        );
        try {
          final session = Session(
            id: '',
            name: '',
            prompt: msg.content,
            sourceContext: SourceContext(source: ''),
          );
          final newMsg = QueuedMessage(
            id: msg.id,
            sessionId: msg.sessionId,
            content: msg.content,
            createdAt: msg.createdAt,
            type: QueuedMessageType.sessionCreation,
            metadata: session.toJson(), // Minimal metadata recovery
            isDraft:
                true, // Legacy queue items that weren't sent should be drafts
            queueReason: 'Recovered from legacy queue',
            processingErrors: msg.processingErrors,
          );
          _queue[i] = newMsg;
          changed = true;
        } catch (e) {
          debugPrint("Error migrating message ${msg.id}: $e");
        }
      }

      // Fix 2: Ensure correct queueReason for drafts
      if (_queue[i].isDraft &&
          (_queue[i].queueReason == null || _queue[i].queueReason!.isEmpty)) {
        debugPrint("Fixing queueReason for draft message ${msg.id}");
        _queue[i] = _queue[i].copyWith(queueReason: "User saved as draft");
        changed = true;
      }

      // Fix 3: Ensure session creation requests are marked as drafts if they have never been sent (no errors)
      if (_queue[i].type == QueuedMessageType.sessionCreation &&
          !_queue[i].isDraft &&
          (_queue[i].processingErrors.isEmpty) &&
          (_queue[i].queueReason == null)) {
        // If it's just sitting there without errors or reason, assume it's a draft or pending offline
        // But we don't want to auto-send really old stuff?
        // Let's mark as draft to be safe for user review
        debugPrint(
          "Marking unsent session creation request ${msg.id} as draft.",
        );
        _queue[i] = _queue[i].copyWith(
          isDraft: true,
          queueReason: "Restored as draft",
        );
        changed = true;
      }
    }

    if (changed) {
      await _saveQueue();
      debugPrint("Message Queue migrated successfully.");
    }
  }

  Future<void> resyncQueue() async {
    debugPrint("Resyncing/Sanitizing queue...");
    await _migrateQueue();
    notifyListeners();
    debugPrint("Resync complete.");
  }

  Future<void> _saveQueue() async {
    if (_cacheService != null && _authToken != null) {
      await _cacheService!.saveMessageQueue(_authToken!, _queue);
    }
  }

  String addMessage(
    String sessionId,
    String content, {
    String? reason,
    bool isDraft = false,
  }) {
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

  String addCreateSessionRequest(
    Session session, {
    String? reason,
    bool isDraft = false,
  }) {
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

  void updateCreateSessionRequest(
    String id,
    Session session, {
    bool? isDraft,
    String? reason,
  }) {
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
    addMessage(
      sessionId,
      content,
      isDraft: true,
      reason: 'User saved as draft',
    );
  }

  List<QueuedMessage> getDrafts(String sessionId) {
    return _queue.where((m) => m.sessionId == sessionId && m.isDraft).toList();
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

  Future<void> sendQueue(
    JulesClient client, {
    Function(String)? onMessageSent,
    Function(Session)? onSessionCreated,
    Function(String, Object)? onError,
  }) async {
    if (_isOffline) return;

    List<QueuedMessage> remaining = List.from(
      _queue.where((m) => !m.isDraft),
    ); // Skip drafts
    List<QueuedMessage> toRemove = [];

    // Sort by creation time to send in order
    remaining.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final msg in remaining) {
      try {
        if (msg.type == QueuedMessageType.sessionCreation ||
            msg.sessionId == 'new_session') {
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

          final createdSession = await client.createSession(sessionToCreate);
          if (onSessionCreated != null) {
            onSessionCreated(createdSession);
          }
        } else {
          await client.sendMessage(msg.sessionId, msg.content);
        }
        toRemove.add(msg);
        if (onMessageSent != null) onMessageSent(msg.id);
      } catch (e) {
        bool recovered = false;
        // Recovery logic is likely not needed if we handle new_session above, but keeping for safety
        // ... (Actually the above logic replaces the catch block recovery for 404 on new_session)

        if (!recovered) {
          if (onError != null) onError(msg.id, e);

          // Record error on the message
          final index = _queue.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            final currentErrors = List<String>.from(
              _queue[index].processingErrors,
            );
            currentErrors.add(e.toString());
            _queue[index] = _queue[index].copyWith(
              processingErrors: currentErrors,
            );
            await _saveQueue();
            notifyListeners();
          }

          // Stop on first error to preserve order
          break;
        }
      }
    }

    _queue.removeWhere((m) => toRemove.contains(m));
    await _saveQueue();
    notifyListeners();
  }

  Future<String> importLegacyQueue(String filePath) async {
    try {
      final file = File(filePath);
      debugPrint("Attempting to import from: $filePath");

      if (!await file.exists()) {
        return "File not found: $filePath";
      }

      final jsonString = await file.readAsString();
      debugPrint("Read ${jsonString.length} chars.");

      final List<dynamic> jsonList = jsonDecode(jsonString);
      debugPrint("Decoded ${jsonList.length} items.");

      int imported = 0;
      int skipped = 0;

      for (var item in jsonList) {
        try {
          final message = QueuedMessage.fromJson(item);
          final existingIndex = _queue.indexWhere((m) => m.id == message.id);

          if (existingIndex == -1) {
            _queue.add(message);
            imported++;
            debugPrint("Imported new item: ${message.id}");
          } else {
            // Update/Merge logic: Overwrite with imported version to ensure tags/reason are restored
            // especially for legacy items where local might be malformed or missing metadata.
            _queue[existingIndex] = message;
            imported++; // Count as imported/updated
            debugPrint("Updated existing item: ${message.id}");
          }
        } catch (e) {
          debugPrint("Failed to parse item: $e");
        }
      }

      if (imported > 0) {
        await _saveQueue();
        // Run migration on new items just in case they are legacy
        await _migrateQueue();
        notifyListeners();
      }

      return "Process Complete.\nFound: ${jsonList.length}\nImported: $imported\nSkipped: $skipped";
    } catch (e) {
      debugPrint("Failed to import legacy queue: $e");
      return "Error: $e";
    }
  }

  Future<String?> getQueuePathForSessionId(String sessionId) async {
    if (_cacheService == null) return null;
    final file = await _cacheService!.getMessageQueueFileForToken(sessionId);
    return file.path;
  }
}
