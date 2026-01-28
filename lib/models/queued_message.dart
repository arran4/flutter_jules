import 'package:dartobjectutils/dartobjectutils.dart';

enum QueuedMessageType { message, sessionCreation }

enum QueueState {
  /// The message is a draft and should not be sent automatically.
  draft,

  /// The message is queued and waiting to be picked up by the sender.
  queued,

  /// The message is currently being sent to the server.
  sending,

  /// The message failed to send. Check [processingErrors] for details.
  failed,

  /// The message was successfully sent to the server.
  /// Corresponds to "In Jules" / "Use Jules State".
  sent,

  /// The message is no longer in Jules or has been lost/discarded.
  vestigial,
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
  final QueueState state;
  final String? requestId;

  // Helper getters for backward compatibility during refactor
  bool get isDraft => state == QueueState.draft;

  QueuedMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.createdAt,
    this.type = QueuedMessageType.message,
    this.metadata,
    this.queueReason,
    this.processingErrors = const [],
    this.state = QueueState.queued,
    this.requestId,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    // Backward compatibility for isDraft
    QueueState initialState = QueueState.queued;
    if (json.containsKey('state')) {
      initialState = _getEnumPropOrDefault(
        json,
        'state',
        QueueState.values,
        QueueState.queued,
      )!;
    } else if (json.containsKey('isDraft')) {
      final isDraft = getBooleanPropOrDefault(json, 'isDraft', false);
      initialState = isDraft ? QueueState.draft : QueueState.queued;
    }

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
      processingErrors: (json['processingErrors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      state: initialState,
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
      'state': state.toString().split('.').last,
      'isDraft':
          state == QueueState.draft, // Maintain for legacy readers if any
      if (requestId != null) 'requestId': requestId,
    };
  }

  QueuedMessage copyWith({
    String? content,
    String? sessionId,
    Map<String, dynamic>? metadata,
    String? queueReason,
    List<String>? processingErrors,
    QueueState? state,
    bool? isDraft, // Deprecated, mapped to state
    String? requestId,
  }) {
    // Handle legacy isDraft argument
    QueueState newState = state ?? this.state;
    if (isDraft != null) {
      newState = isDraft ? QueueState.draft : QueueState.queued;
    }

    return QueuedMessage(
      id: id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      createdAt: createdAt,
      type: type,
      metadata: metadata ?? this.metadata,
      queueReason: queueReason ?? this.queueReason,
      processingErrors: processingErrors ?? this.processingErrors,
      state: newState,
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
