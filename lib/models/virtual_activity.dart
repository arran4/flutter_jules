import 'activity.dart';
import 'pending_message.dart';
import 'queued_message.dart';

enum VirtualActivityStatus { sending, sent, failed, draft, serverConfirmed }

/// A unified model representing a message/activity in the timeline,
/// handling both server-side activities and local transient states.
class VirtualActivity {
  final String id;
  final String content;
  final DateTime timestamp;
  final VirtualActivityStatus status;

  // Underlying source objects
  final Activity? originalActivity;
  final PendingMessage? originalPending;
  final QueuedMessage? originalQueued;

  VirtualActivity._({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.status,
    this.originalActivity,
    this.originalPending,
    this.originalQueued,
  });

  factory VirtualActivity.fromActivity(Activity activity) {
    // Determine content from activity
    String content = '';
    if (activity.userMessaged != null) {
      content = activity.userMessaged!.userMessage;
    } else if (activity.agentMessaged != null) {
      content = activity.agentMessaged!.agentMessage;
    } else {
      content = activity.description;
    }

    return VirtualActivity._(
      id: activity.id,
      content: content,
      timestamp: DateTime.parse(activity.createTime),
      status: VirtualActivityStatus.serverConfirmed,
      originalActivity: activity,
    );
  }

  factory VirtualActivity.fromPending(PendingMessage pending) {
    VirtualActivityStatus status;
    if (pending.status == PendingMessageStatus.sent) {
      status = VirtualActivityStatus.sent;
    } else {
      status = VirtualActivityStatus.sending;
    }

    return VirtualActivity._(
      id: "pending-${pending.id}",
      content: pending.content,
      timestamp: pending.timestamp,
      status: status,
      originalPending: pending,
    );
  }

  factory VirtualActivity.fromQueued(QueuedMessage queued) {
    return VirtualActivity._(
      id: "queued-${queued.id}",
      content: queued.content,
      timestamp: queued.createdAt,
      status: queued.isDraft
          ? VirtualActivityStatus.draft
          : VirtualActivityStatus.failed,
      originalQueued: queued,
    );
  }

  /// Generates a "virtual" Activity object compatible with existing ActivityItem widgets.
  /// This bridges the new state machine with the legacy rendering layer.
  Activity toActivity() {
    if (originalActivity != null) {
      return originalActivity!;
    }

    // Local state variables
    bool isPending = false;
    String? pendingId;
    bool isSent = false;
    bool isQueued = false;
    String? queueReason;
    List<String>? processingErrors;
    bool hasMismatch = false;

    // We still use unmappedProps for miscellaneous metadata like 'isDraft' or 'metadata'
    // if they don't have a dedicated field in Activity yet.
    Map<String, dynamic> unmappedProps = {};
    String description = "";

    switch (status) {
      case VirtualActivityStatus.sending:
        description = "Sending...";
        isPending = true;
        pendingId = originalPending?.id;
        break;
      case VirtualActivityStatus.sent:
        description = "Sent";
        isSent = true;
        pendingId = originalPending?.id;
        break;
      case VirtualActivityStatus.failed:
        description = "Sending Failed";
        isQueued = true;
        queueReason = originalQueued?.queueReason;
        processingErrors = originalQueued?.processingErrors;
        unmappedProps['metadata'] = originalQueued?.metadata;
        break;
      case VirtualActivityStatus.draft:
        description = "Draft";
        unmappedProps['isDraft'] = true;
        break;
      case VirtualActivityStatus.serverConfirmed:
        // Should have been returned via originalActivity check
        break;
    }

    if (originalPending?.hasMismatch == true &&
        status != VirtualActivityStatus.sent) {
      hasMismatch = true;
    }

    return Activity(
      name: id, // Virtual name
      id: id,
      createTime: timestamp.toIso8601String(),
      userMessaged: UserMessaged(userMessage: content),
      description: description,
      isPending: isPending,
      pendingId: pendingId,
      isSent: isSent,
      isQueued: isQueued,
      queueReason: queueReason,
      processingErrors: processingErrors,
      hasMismatch: hasMismatch,
      unmappedProps: unmappedProps,
    );
  }
}
