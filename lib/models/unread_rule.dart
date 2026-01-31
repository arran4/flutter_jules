enum RuleType {
  prStatus,
  ciStatus,
  // sessionState, // Disabled for now, as session state changes are always unread
  contentUpdate, // Generic update (comment, commit, etc)
}

enum RuleAction { markUnread, markRead, doNothing }

class UnreadRule {
  final String id;
  final RuleType type;
  final String? fromValue;
  final String? toValue;
  final RuleAction action;
  final bool enabled;

  UnreadRule({
    required this.id,
    required this.type,
    this.fromValue,
    this.toValue,
    required this.action,
    this.enabled = true,
  });

  factory UnreadRule.fromJson(Map<String, dynamic> json) {
    return UnreadRule(
      id: json['id'] as String,
      type: RuleType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => RuleType.contentUpdate,
      ),
      fromValue: json['fromValue'] as String?,
      toValue: json['toValue'] as String?,
      action: RuleAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
        orElse: () => RuleAction.markUnread,
      ),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'fromValue': fromValue,
      'toValue': toValue,
      'action': action.toString().split('.').last,
      'enabled': enabled,
    };
  }

  UnreadRule copyWith({
    String? id,
    RuleType? type,
    String? fromValue,
    String? toValue,
    RuleAction? action,
    bool? enabled,
  }) {
    return UnreadRule(
      id: id ?? this.id,
      type: type ?? this.type,
      fromValue: fromValue ?? this.fromValue,
      toValue: toValue ?? this.toValue,
      action: action ?? this.action,
      enabled: enabled ?? this.enabled,
    );
  }

  String get description {
    String typeStr;
    switch (type) {
      case RuleType.prStatus:
        typeStr = "PR Status";
        break;
      case RuleType.ciStatus:
        typeStr = "CI Status";
        break;
      // case RuleType.sessionState:
      //   typeStr = "Session State";
      //   break;
      case RuleType.contentUpdate:
        typeStr = "Content Update";
        break;
    }

    String condition = "";
    if (fromValue != null && toValue != null) {
      condition = "changes from '$fromValue' to '$toValue'";
    } else if (fromValue != null) {
      condition = "changes from '$fromValue'";
    } else if (toValue != null) {
      condition = "changes to '$toValue'";
    } else {
      condition = "changes";
    }

    String actionStr;
    switch (action) {
      case RuleAction.markUnread:
        actionStr = "Mark Unread";
        break;
      case RuleAction.markRead:
        actionStr = "Mark Read";
        break;
      case RuleAction.doNothing:
        actionStr = "Do Nothing";
        break;
    }

    return "$typeStr $condition -> $actionStr";
  }
}
