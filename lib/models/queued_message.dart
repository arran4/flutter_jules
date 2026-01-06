import 'package:dartobjectutils/dartobjectutils.dart';

class QueuedMessage {
  final String id;
  final String sessionId;
  final String content;
  final DateTime createdAt;

  QueuedMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.createdAt,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: getStringPropOrThrow(json, 'id'),
      sessionId: getStringPropOrThrow(json, 'sessionId'),
      content: getStringPropOrThrow(json, 'content'),
      createdAt: DateTime.parse(getStringPropOrThrow(json, 'createdAt')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  QueuedMessage copyWith({
    String? content,
  }) {
    return QueuedMessage(
      id: id,
      sessionId: sessionId,
      content: content ?? this.content,
      createdAt: createdAt,
    );
  }
}
