import 'package:dartobjectutils/dartobjectutils.dart';

enum QueuedMessageType {
  message,
  sessionCreation,
}

class QueuedMessage {
  final String id;
  final String sessionId;
  final String content;
  final DateTime createdAt;
  final QueuedMessageType type;
  final Map<String, dynamic>? metadata;

  QueuedMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.createdAt,
    this.type = QueuedMessageType.message,
    this.metadata,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: getStringPropOrThrow(json, 'id'),
      sessionId: getStringPropOrThrow(json, 'sessionId'),
      content: getStringPropOrThrow(json, 'content'),
      createdAt: DateTime.parse(getStringPropOrThrow(json, 'createdAt')),
      type: getEnumPropOrDefault(
          json, 'type', QueuedMessageType.values, QueuedMessageType.message)!,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString().split('.').last,
      if (metadata != null) 'metadata': metadata,
    };
  }

  QueuedMessage copyWith({
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return QueuedMessage(
      id: id,
      sessionId: sessionId,
      content: content ?? this.content,
      createdAt: createdAt,
      type: type,
      metadata: metadata ?? this.metadata,
    );
  }
}

// TODO update with dartobjectutils when it support this
T? getEnumPropOrDefault<T>(
    Map<String, dynamic> json, String key, List<T> values, T? defaultValue) {
  if (json[key] == null) {
    return defaultValue;
  }
  return values.firstWhere(
    (e) => e.toString().split('.').last == json[key],
    orElse: () => defaultValue as T,
  );
}
