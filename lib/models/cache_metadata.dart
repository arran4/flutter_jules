
class CacheMetadata {
  final DateTime firstSeen;
  final DateTime lastRetrieved;
  final DateTime? lastOpened; // When the user actually clicked/viewed it
  final DateTime? lastUpdated; // When the content last changed (detected delta)
  final List<String> labels; // e.g. ["priority", "favorite"]

  CacheMetadata({
    required this.firstSeen,
    required this.lastRetrieved,
    this.lastOpened,
    this.lastUpdated,
    this.labels = const [],
  });
  
  // Convenience Getters
  
  // "New" (Unread Type A): Never opened, AND discovered recently (within 1 hour of refresh).
  // Matches "Not opened at all", but expires if data refresh occurs >1h after discovery.
  bool get isNew {
    if (lastOpened != null) return false;
    
    // If the latest refresh (lastRetrieved) happened more than 1 hour after we first saw this item,
    // it is no longer considered "New".
    if (lastRetrieved.difference(firstSeen).inHours >= 1) {
      return false;
    }
    
    return true; 
  }
  
  // "Updated" (Unread Type B): Opened before, but content changed since last open.
  // Matches "Changed since the previous data reset" (assuming reset = open).
  // AND logic ensures we don't mark read items as updated, nor new items as updated (UI separates them).
  bool get isUpdated => 
      lastOpened != null && lastUpdated != null && lastUpdated!.isAfter(lastOpened!);
  
  // "Unread": Either never opened (New) OR opened but changed (Updated).
  // Matches "Changed ... OR not opened at all".
  bool get isUnread => isNew || isUpdated;

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      firstSeen: DateTime.parse(json['firstSeen']),
      lastRetrieved: DateTime.parse(json['lastRetrieved']),
      lastOpened: json['lastOpened'] != null
          ? DateTime.parse(json['lastOpened'])
          : null,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
      labels: (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstSeen': firstSeen.toIso8601String(),
      'lastRetrieved': lastRetrieved.toIso8601String(),
      if (lastOpened != null) 'lastOpened': lastOpened!.toIso8601String(),
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      'labels': labels,
    };
  }

  CacheMetadata copyWith({
    DateTime? firstSeen,
    DateTime? lastRetrieved,
    DateTime? lastOpened,
    DateTime? lastUpdated,
    List<String>? labels,
  }) {
    return CacheMetadata(
      firstSeen: firstSeen ?? this.firstSeen,
      lastRetrieved: lastRetrieved ?? this.lastRetrieved,
      lastOpened: lastOpened ?? this.lastOpened,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      labels: labels ?? this.labels,
    );
  }
}
