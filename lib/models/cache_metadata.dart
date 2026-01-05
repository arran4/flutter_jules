class CacheMetadata {
  final DateTime firstSeen;
  final DateTime lastRetrieved;
  final DateTime? lastOpened; // When the user actually clicked/viewed it
  final DateTime? lastPrOpened; // When the user opened the PR
  final DateTime? lastUpdated; // When the content last changed (detected delta)
  final List<String> labels; // e.g. ["priority", "favorite"]

  CacheMetadata({
    required this.firstSeen,
    required this.lastRetrieved,
    this.lastOpened,
    this.lastPrOpened,
    this.lastUpdated,
    this.labels = const [],
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
    };
  }

  CacheMetadata copyWith({
    DateTime? firstSeen,
    DateTime? lastRetrieved,
    DateTime? lastOpened,
    DateTime? lastPrOpened,
    DateTime? lastUpdated,
    List<String>? labels,
  }) {
    return CacheMetadata(
      firstSeen: firstSeen ?? this.firstSeen,
      lastRetrieved: lastRetrieved ?? this.lastRetrieved,
      lastOpened: lastOpened ?? this.lastOpened,
      lastPrOpened: lastPrOpened ?? this.lastPrOpened,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      labels: labels ?? this.labels,
    );
  }
}
