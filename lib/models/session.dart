import 'enums.dart';
import 'source.dart';

class PullRequest {
  final String url;
  final String title;
  final String description;

  PullRequest({
    required this.url,
    required this.title,
    required this.description,
  });

  factory PullRequest.fromJson(Map<String, dynamic> json) {
    return PullRequest(
      url: json['url'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
    };
  }
}

class SessionOutput {
  final PullRequest? pullRequest;

  SessionOutput({this.pullRequest});

  factory SessionOutput.fromJson(Map<String, dynamic> json) {
    return SessionOutput(
      pullRequest: json['pullRequest'] != null
          ? PullRequest.fromJson(json['pullRequest'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (pullRequest != null) {
      map['pullRequest'] = pullRequest!.toJson();
    }
    return map;
  }
}

class Session {
  final String name;
  final String id;
  final String prompt;
  final SourceContext sourceContext;
  final String? title;
  final bool? requirePlanApproval;
  final AutomationMode? automationMode;
  final String? createTime;
  final String? updateTime;
  final SessionState? state;
  final String? url;
  final List<SessionOutput>? outputs;

  Session({
    required this.name,
    required this.id,
    required this.prompt,
    required this.sourceContext,
    this.title,
    this.requirePlanApproval,
    this.automationMode,
    this.createTime,
    this.updateTime,
    this.state,
    this.url,
    this.outputs,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      name: json['name'] as String,
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      sourceContext: SourceContext.fromJson(json['sourceContext']),
      title: json['title'] as String?,
      requirePlanApproval: json['requirePlanApproval'] as bool?,
      automationMode: json['automationMode'] != null
          ? AutomationMode.values.firstWhere(
              (e) => e.toString() == 'AutomationMode.${json['automationMode']}',
              orElse: () => AutomationMode.AUTOMATION_MODE_UNSPECIFIED)
          : null,
      createTime: json['createTime'] as String?,
      updateTime: json['updateTime'] as String?,
      state: json['state'] != null
          ? SessionState.values.firstWhere(
              (e) => e.toString() == 'SessionState.${json['state']}',
              orElse: () => SessionState.STATE_UNSPECIFIED)
          : null,
      url: json['url'] as String?,
      outputs: (json['outputs'] as List<dynamic>?)
          ?.map((e) => SessionOutput.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
      'prompt': prompt,
      'sourceContext': sourceContext.toJson(),
    };
    if (title != null) map['title'] = title;
    if (requirePlanApproval != null) map['requirePlanApproval'] = requirePlanApproval;
    if (automationMode != null) {
      map['automationMode'] = automationMode.toString().split('.').last;
    }
    if (createTime != null) map['createTime'] = createTime;
    if (updateTime != null) map['updateTime'] = updateTime;
    if (state != null) {
      map['state'] = state.toString().split('.').last;
    }
    if (url != null) map['url'] = url;
    if (outputs != null) {
      map['outputs'] = outputs!.map((e) => e.toJson()).toList();
    }
    return map;
  }
}
