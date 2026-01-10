import '../models/search_filter.dart';
import '../models/filter_element.dart';

enum BulkActionType {
  openPrInBrowser,
  markAsRead,
  markAsUnread,
  hide,
  unhide,
  refreshSession, // Refresh Session + Conditional PR Status
  deepRefresh, // Session + Activities + PR status
  watchSession,
  unwatchSession,
  openJulesLink,
  quickReply,
  viewSourceRepo, // renamed from View source repo
  forceRefreshPrStatus,
  forceApprovePlan,
  duplicateSession,
  sleep,
}

extension BulkActionTypeExtension on BulkActionType {
  String get displayName {
    switch (this) {
      case BulkActionType.openPrInBrowser:
        return 'Open PR in Browser';
      case BulkActionType.markAsRead:
        return 'Mark as Read';
      case BulkActionType.markAsUnread:
        return 'Mark as Unread';
      case BulkActionType.hide:
        return 'Hide';
      case BulkActionType.unhide:
        return 'Unhide';
      case BulkActionType.refreshSession:
        return 'Refresh Session';
      case BulkActionType.deepRefresh:
        return 'Deep/Full Refresh';
      case BulkActionType.watchSession:
        return 'Watch Session';
      case BulkActionType.unwatchSession:
        return 'Unwatch Session';
      case BulkActionType.openJulesLink:
        return 'Open Jules link';
      case BulkActionType.quickReply:
        return 'Quick Reply';
      case BulkActionType.viewSourceRepo:
        return 'View Source Repository';
      case BulkActionType.forceRefreshPrStatus:
        return 'Force Refresh PR Status';
      case BulkActionType.forceApprovePlan:
        return 'Force Approve Plan';
      case BulkActionType.duplicateSession:
        return 'Duplicate Session';
      case BulkActionType.sleep:
        return 'Sleep (Wait)';
    }
  }

  bool get requiresMessage {
    return this == BulkActionType.quickReply || this == BulkActionType.sleep;
  }
}

class BulkActionStep {
  final BulkActionType type;
  final String? message; // For quickReply or sleep (seconds)

  const BulkActionStep({required this.type, this.message});

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'message': message,
      };

  factory BulkActionStep.fromJson(Map<String, dynamic> json) => BulkActionStep(
        type: BulkActionType.values[json['type']],
        message: json['message'],
      );
}

enum BulkTargetType { visible, filtered }

class BulkJobConfig {
  final BulkTargetType targetType;
  final FilterElement? filterTree; // Only used if filtered
  final List<SortOption> sorts;
  final List<BulkActionStep> actions;
  final int parallelQueries;
  final int waitBetweenSeconds;

  // Execution control
  final int? limit; // Maximum number of sessions to process
  final int offset; // Skip first N sessions
  final bool randomize; // Randomize order before processing
  final bool stopOnError; // Stop entire job if any session fails

  const BulkJobConfig({
    required this.targetType,
    this.filterTree,
    required this.sorts,
    required this.actions,
    this.parallelQueries = 1,
    this.waitBetweenSeconds = 2,
    this.limit,
    this.offset = 0,
    this.randomize = false,
    this.stopOnError = false,
  });
}

enum BulkJobStatus { pending, running, paused, canceled, completed }

class BulkLogEntry {
  final DateTime timestamp;
  final String message;
  final bool isError;
  final String? sessionId;

  const BulkLogEntry({
    required this.message,
    required this.timestamp,
    this.isError = false,
    this.sessionId,
  });
}
