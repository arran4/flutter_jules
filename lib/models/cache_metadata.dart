
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
  // "New" if never opened
  bool get isNew => lastOpened == null; // effectively "Unread" too if we conflate them
  
  // "Updated" if content changed since last open
  bool get isUpdated => 
      lastUpdated != null && (lastOpened == null || lastUpdated!.isAfter(lastOpened!));
  
  // "Unread" generally means New OR Updated
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
