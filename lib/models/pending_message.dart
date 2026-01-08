import 'package:dartobjectutils/dartobjectutils.dart';

class PendingMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool hasMismatch;

  PendingMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    this.hasMismatch = false,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    return PendingMessage(
      id: getStringPropOrThrow(json, 'id'),
      content: getStringPropOrThrow(json, 'content'),
      timestamp: DateTime.parse(getStringPropOrThrow(json, 'timestamp')),
      hasMismatch: getBooleanPropOrDefault(json, 'hasMismatch', false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'hasMismatch': hasMismatch,
    };
  }

  PendingMessage copyWith({
    String? content,
    bool? hasMismatch,
  }) {
    return PendingMessage(
      id: id,
      content: content ?? this.content,
      timestamp: timestamp,
      hasMismatch: hasMismatch ?? this.hasMismatch,
    );
  }
}
