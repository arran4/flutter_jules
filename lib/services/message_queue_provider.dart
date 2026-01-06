import 'package:flutter/material.dart';
import '../models/queued_message.dart';
import 'cache_service.dart';
import 'jules_client.dart';

class MessageQueueProvider extends ChangeNotifier {
  List<QueuedMessage> _queue = [];
  bool _isOffline = false;
  CacheService? _cacheService;
  String? _authToken;

  List<QueuedMessage> get queue => _queue;
  bool get isOffline => _isOffline;

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
      notifyListeners();
    }
  }

  Future<void> _saveQueue() async {
    if (_cacheService != null && _authToken != null) {
      await _cacheService!.saveMessageQueue(_authToken!, _queue);
    }
  }

  void addMessage(String sessionId, String content) {
    final message = QueuedMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: sessionId,
      content: content,
      createdAt: DateTime.now(),
    );
    _queue.add(message);
    _saveQueue();
    notifyListeners();
  }

  void updateMessage(String id, String newContent) {
    final index = _queue.indexWhere((m) => m.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(content: newContent);
      _saveQueue();
      notifyListeners();
    }
  }

  void deleteMessage(String id) {
    _queue.removeWhere((m) => m.id == id);
    _saveQueue();
    notifyListeners();
  }

  // Returns true if connection successful
  Future<bool> goOnline(JulesClient client) async {
    try {
      // Test endpoint with a lightweight call
      await client.listSessions(pageSize: 1);
      _isOffline = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Still offline
      // print("Go Online check failed: $e");
      return false;
    }
  }

  Future<void> sendQueue(JulesClient client,
      {Function(String)? onMessageSent,
      Function(String, Object)? onError}) async {
    if (_isOffline) return;

    List<QueuedMessage> remaining = List.from(_queue);
    List<QueuedMessage> toRemove = [];

    // Sort by creation time to send in order
    remaining.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final msg in remaining) {
      try {
        await client.sendMessage(msg.sessionId, msg.content);
        toRemove.add(msg);
        if (onMessageSent != null) onMessageSent(msg.id);
      } catch (e) {
        if (onError != null) onError(msg.id, e);
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
