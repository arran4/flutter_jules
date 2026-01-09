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
  final String? queueReason;
  final List<String> processingErrors;
  final bool isDraft;

  QueuedMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.createdAt,
    this.type = QueuedMessageType.message,
    this.metadata,
    this.queueReason,
    this.processingErrors = const [],
    this.isDraft = false,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: getStringPropOrThrow(json, 'id'),
      sessionId: getStringPropOrThrow(json, 'sessionId'),
      content: getStringPropOrThrow(json, 'content'),
      createdAt: DateTime.parse(getStringPropOrThrow(json, 'createdAt')),
      type: _getEnumPropOrDefault(
          json, 'type', QueuedMessageType.values, QueuedMessageType.message)!,
      metadata: json['metadata'] as Map<String, dynamic>?,
      queueReason: getStringPropOrDefault(json, 'queueReason', null),
      processingErrors: (json['processingErrors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isDraft: getBooleanPropOrDefault(json, 'isDraft', false),
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
      if (queueReason != null) 'queueReason': queueReason,
      if (queueReason != null) 'queueReason': queueReason,
      'processingErrors': processingErrors,
      'isDraft': isDraft,
    };
  }

  QueuedMessage copyWith({
    String? content,
    Map<String, dynamic>? metadata,
    String? queueReason,
    List<String>? processingErrors,
    bool? isDraft,
  }) {
    return QueuedMessage(
      id: id,
      sessionId: sessionId,
      content: content ?? this.content,
      createdAt: createdAt,
      type: type,
      metadata: metadata ?? this.metadata,
      queueReason: queueReason ?? this.queueReason,
      processingErrors: processingErrors ?? this.processingErrors,
      isDraft: isDraft ?? this.isDraft,
    );
  }
}

// TODO update with dartobjectutils when it support this
T? _getEnumPropOrDefault<T>(
    Map<String, dynamic> json, String key, List<T> values, T? defaultValue) {
  if (json[key] == null) {
    return defaultValue;
  }
  return values.firstWhere(
    (e) => e.toString().split('.').last == json[key],
    orElse: () => defaultValue as T,
  );
}
