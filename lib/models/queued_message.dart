import 'package:dartobjectutils/dartobjectutils.dart';

enum QueuedMessageType { message, sessionCreation }

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
  final String? requestId;

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
    this.requestId,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: getStringPropOrThrow(json, 'id'),
      sessionId: getStringPropOrThrow(json, 'sessionId'),
      content: getStringPropOrThrow(json, 'content'),
      createdAt: DateTime.parse(getStringPropOrThrow(json, 'createdAt')),
      type: _getEnumPropOrDefault(
        json,
        'type',
        QueuedMessageType.values,
        QueuedMessageType.message,
      )!,
      metadata: json['metadata'] as Map<String, dynamic>?,
      queueReason: getStringPropOrDefault(json, 'queueReason', null),
      processingErrors:
          (json['processingErrors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isDraft: getBooleanPropOrDefault(json, 'isDraft', false),
      requestId: getStringPropOrDefault(json, 'requestId', null),
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
      'processingErrors': processingErrors,
      'isDraft': isDraft,
      if (requestId != null) 'requestId': requestId,
    };
  }

  QueuedMessage copyWith({
    String? content,
    String? sessionId,
    Map<String, dynamic>? metadata,
    String? queueReason,
    List<String>? processingErrors,
    bool? isDraft,
    String? requestId,
  }) {
    return QueuedMessage(
      id: id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      createdAt: createdAt,
      type: type,
      metadata: metadata ?? this.metadata,
      queueReason: queueReason ?? this.queueReason,
      processingErrors: processingErrors ?? this.processingErrors,
      isDraft: isDraft ?? this.isDraft,
      requestId: requestId ?? this.requestId,
    );
  }
}

// TODO: Replace with dartobjectutils' getEnumPropOrDefault when available.
T? _getEnumPropOrDefault<T>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
  T? defaultValue,
) {
  final value = getStringPropOrDefault<String?>(json, key, null);
  if (value == null) {
    return defaultValue;
  }
  for (final element in values) {
    if (element.toString().split('.').last == value) {
      return element;
    }
  }
  return defaultValue;
}
