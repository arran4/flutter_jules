import 'pending_message.dart';
import 'package:dartobjectutils/dartobjectutils.dart'; // Ensure this is available if not already

class CacheMetadata {
  final DateTime firstSeen;
  final DateTime lastRetrieved;
  final DateTime? lastOpened; // When the user actually clicked/viewed it
  final DateTime? lastPrOpened; // When the user opened the PR
  final DateTime? lastUpdated; // When the content last changed (detected delta)
  final List<String> labels;
  final bool isWatched;
  final bool isHidden;
  final bool
      hasPendingUpdates; // True if message sent but not yet fully refreshed/synced response
  final List<PendingMessage> pendingMessages;

  CacheMetadata({
    required this.firstSeen,
    required this.lastRetrieved,
    this.lastOpened,
    this.lastPrOpened,
    this.lastUpdated,
    this.labels = const [],
    this.isWatched = false,
    this.hasPendingUpdates = false,
    this.isHidden = false,
    this.pendingMessages = const [],
  });

  // Convenience Getters

  // "New": Discovered recently (within 1 hour of latest refresh).
  // Expires if opened OR if refreshed > 1 hour after discovery.
  bool get isNew {
    if (lastOpened != null) return false;
    return lastRetrieved.difference(firstSeen).inHours < 1;
  }

  // "Updated": Updated recently (within 1 hour of latest refresh).
  // Expires if opened OR if refreshed > 1 hour after update.
  bool get isUpdated {
    if (lastUpdated == null) return false;
    if (lastOpened != null && lastOpened!.isAfter(lastUpdated!)) return false;
    return lastRetrieved.difference(lastUpdated!).inHours < 1;
  }

  // "Unread": Not viewed since creation or last update.
  // Cleared by reading (opening). Can be set manually (Circle back to Unread).
  bool get isUnread {
    if (lastOpened == null) return true;
    if (lastUpdated != null && lastUpdated!.isAfter(lastOpened!)) return true;
    return false;
  }

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      firstSeen: DateTime.parse(json['firstSeen']),
      lastRetrieved: DateTime.parse(json['lastRetrieved']),
      lastOpened: json['lastOpened'] != null
          ? DateTime.parse(json['lastOpened'])
          : null,
      lastPrOpened: json['lastPrOpened'] != null
          ? DateTime.parse(json['lastPrOpened'])
          : null,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isWatched: json['isWatched'] ?? false,
      hasPendingUpdates: json['hasPendingUpdates'] ?? false,
      isHidden: json['isHidden'] ?? false,
      pendingMessages: getObjectArrayPropOrDefaultFunction(
          json, 'pendingMessages', PendingMessage.fromJson, () => []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstSeen': firstSeen.toIso8601String(),
      'lastRetrieved': lastRetrieved.toIso8601String(),
      if (lastOpened != null) 'lastOpened': lastOpened!.toIso8601String(),
      if (lastPrOpened != null) 'lastPrOpened': lastPrOpened!.toIso8601String(),
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      'labels': labels,
      'isWatched': isWatched,
      'hasPendingUpdates': hasPendingUpdates,
      'isHidden': isHidden,
      'pendingMessages': pendingMessages.map((e) => e.toJson()).toList(),
    };
  }

  CacheMetadata copyWith({
    DateTime? firstSeen,
    DateTime? lastRetrieved,
    DateTime? lastOpened,
    DateTime? lastPrOpened,
    DateTime? lastUpdated,
    List<String>? labels,
    bool? isWatched,
    bool? hasPendingUpdates,
    bool? isHidden, // Fixed
    List<PendingMessage>? pendingMessages,
  }) {
    return CacheMetadata(
      firstSeen: firstSeen ?? this.firstSeen,
      lastRetrieved: lastRetrieved ?? this.lastRetrieved,
      lastOpened: lastOpened ?? this.lastOpened,
      lastPrOpened: lastPrOpened ?? this.lastPrOpened,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      labels: labels ?? this.labels,
      isWatched: isWatched ?? this.isWatched,
      hasPendingUpdates: hasPendingUpdates ?? this.hasPendingUpdates,
      isHidden: isHidden ?? this.isHidden,
      pendingMessages: pendingMessages ?? this.pendingMessages,
    );
  }
}
