import 'package:dartobjectutils/dartobjectutils.dart';
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
      url: getStringPropOrThrow(json, 'url'),
      title: getStringPropOrThrow(json, 'title'),
      description: getStringPropOrThrow(json, 'description'),
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
      pullRequest: getObjectFunctionPropOrDefault(json, 'pullRequest', PullRequest.fromJson, null),
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
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      prompt: getStringPropOrThrow(json, 'prompt'),
      sourceContext: getObjectFunctionPropOrThrow(json, 'sourceContext', SourceContext.fromJson),
      title: getStringPropOrDefault(json, 'title', null),
      requirePlanApproval: getBooleanPropOrDefault(json, 'requirePlanApproval', null),
      automationMode: getEnumPropOrDefault(json, 'automationMode', AutomationMode.values, AutomationMode.AUTOMATION_MODE_UNSPECIFIED),
      createTime: getStringPropOrDefault(json, 'createTime', null),
      updateTime: getStringPropOrDefault(json, 'updateTime', null),
      state: getEnumPropOrDefault(json, 'state', SessionState.values, SessionState.STATE_UNSPECIFIED),
      url: getStringPropOrDefault(json, 'url', null),
      outputs: getObjectArrayPropOrDefaultFunction(json, 'outputs', SessionOutput.fromJson, null),
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

T? getEnumPropOrDefault<T>(Map<String, dynamic> json, String key, List<T> values, T? defaultValue) {
  if (json[key] == null) {
      return defaultValue;
  }
  return values.firstWhere(
    (e) => e.toString().split('.').last == json[key],
    orElse: () => defaultValue as T,
  );
}
