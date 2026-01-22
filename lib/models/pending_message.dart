import 'package:dartobjectutils/dartobjectutils.dart';

enum PendingMessageStatus { sending, sent }

class PendingMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool hasMismatch;
  final PendingMessageStatus status;

  PendingMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    this.hasMismatch = false,
    this.status = PendingMessageStatus.sending,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    return PendingMessage(
      id: getStringPropOrThrow(json, 'id'),
      content: getStringPropOrThrow(json, 'content'),
      timestamp: DateTime.parse(getStringPropOrThrow(json, 'timestamp')),
      hasMismatch: getBooleanPropOrDefault(json, 'hasMismatch', false),
      status: _getStatus(json['status']),
    );
  }

  static PendingMessageStatus _getStatus(String? status) {
    if (status == 'sent') return PendingMessageStatus.sent;
    return PendingMessageStatus.sending;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'hasMismatch': hasMismatch,
      'status': status.name,
    };
  }

  PendingMessage copyWith({
    String? content,
    bool? hasMismatch,
    PendingMessageStatus? status,
  }) {
    return PendingMessage(
      id: id,
      content: content ?? this.content,
      timestamp: timestamp,
      hasMismatch: hasMismatch ?? this.hasMismatch,
      status: status ?? this.status,
    );
  }
}
