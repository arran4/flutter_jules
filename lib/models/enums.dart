enum AutomationMode {
  // ignore: constant_identifier_names
  AUTOMATION_MODE_UNSPECIFIED,
  // ignore: constant_identifier_names
  AUTO_CREATE_PR,
}

enum SessionState {
  // ignore: constant_identifier_names
  STATE_UNSPECIFIED,
  // ignore: constant_identifier_names
  QUEUED,
  // ignore: constant_identifier_names
  PLANNING,
  // ignore: constant_identifier_names
  AWAITING_PLAN_APPROVAL,
  // ignore: constant_identifier_names
  AWAITING_USER_FEEDBACK,
  // ignore: constant_identifier_names
  IN_PROGRESS,
  // ignore: constant_identifier_names
  PAUSED,
  // ignore: constant_identifier_names
  FAILED,
  // ignore: constant_identifier_names
  COMPLETED;

  String get displayName {
    switch (this) {
      case SessionState.STATE_UNSPECIFIED:
        return 'Unspecified';
      case SessionState.QUEUED:
        return 'Queued';
      case SessionState.PLANNING:
        return 'Planning';
      case SessionState.AWAITING_PLAN_APPROVAL:
        return 'Awaiting Plan Approval';
      case SessionState.AWAITING_USER_FEEDBACK:
        return 'Awaiting Feedback';
      case SessionState.IN_PROGRESS:
        return 'In Progress';
      case SessionState.PAUSED:
        return 'Paused';
      case SessionState.FAILED:
        return 'Failed';
      case SessionState.COMPLETED:
        return 'Completed';
    }
  }

  String get description {
    switch (this) {
      case SessionState.STATE_UNSPECIFIED:
        return 'The state is unspecified.';
      case SessionState.QUEUED:
        return 'The session is queued.';
      case SessionState.PLANNING:
        return 'The agent is planning.';
      case SessionState.AWAITING_PLAN_APPROVAL:
        return 'The agent is waiting for plan approval.';
      case SessionState.AWAITING_USER_FEEDBACK:
        return 'The agent is waiting for user feedback.';
      case SessionState.IN_PROGRESS:
        return 'The session is in progress.';
      case SessionState.PAUSED:
        return 'The session is paused.';
      case SessionState.FAILED:
        return 'The session has failed.';
      case SessionState.COMPLETED:
        return 'The session has completed.';
    }
  }
}
