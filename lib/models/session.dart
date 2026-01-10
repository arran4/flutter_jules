import 'package:dartobjectutils/dartobjectutils.dart';
import 'enums.dart';
import 'source.dart';
import 'media.dart';

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
    return {'url': url, 'title': title, 'description': description};
  }
}

class SessionOutput {
  final PullRequest? pullRequest;

  SessionOutput({this.pullRequest});

  factory SessionOutput.fromJson(Map<String, dynamic> json) {
    return SessionOutput(
      pullRequest: getObjectFunctionPropOrDefault(
        json,
        'pullRequest',
        PullRequest.fromJson,
        null,
      ),
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
  final List<Media>? images;
  final int? currentStep;
  final int? totalSteps;
  final String? currentAction;
  final String? prStatus;
  final String? scheduledTime;
  final bool? isRepeating;
  final String? repetitionSchedule;

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
    this.images,
    this.currentStep,
    this.totalSteps,
    this.currentAction,
    this.prStatus,
    this.scheduledTime,
    this.isRepeating,
    this.repetitionSchedule,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      prompt: getStringPropOrThrow(json, 'prompt'),
      sourceContext: getObjectFunctionPropOrThrow(
        json,
        'sourceContext',
        SourceContext.fromJson,
      ),
      title: getStringPropOrDefault(json, 'title', null),
      requirePlanApproval: getBooleanPropOrDefault(
        json,
        'requirePlanApproval',
        false,
      ),
      automationMode: getEnumPropOrDefault(
        json,
        'automationMode',
        AutomationMode.values,
        AutomationMode.AUTOMATION_MODE_UNSPECIFIED,
      ),
      createTime: getStringPropOrDefault(json, 'createTime', null),
      updateTime: getStringPropOrDefault(json, 'updateTime', null),
      state: getEnumPropOrDefault(
        json,
        'state',
        SessionState.values,
        SessionState.STATE_UNSPECIFIED,
      ),
      url: getStringPropOrDefault(json, 'url', null),
      outputs: getObjectArrayPropOrDefaultFunction(
        json,
        'outputs',
        SessionOutput.fromJson,
        () => null,
      ),
      images: getObjectArrayPropOrDefaultFunction(
        json,
        'images',
        Media.fromJson,
        () => null,
      ),
      currentStep: getNumberPropOrDefault<num?>(
        json,
        'currentStep',
        null,
      )?.toInt(),
      totalSteps: getNumberPropOrDefault<num?>(
        json,
        'totalSteps',
        null,
      )?.toInt(),
      currentAction: getStringPropOrDefault(json, 'currentAction', null),
      prStatus: getStringPropOrDefault(json, 'prStatus', null),
      scheduledTime: getStringPropOrDefault(json, 'scheduledTime', null),
      isRepeating: getBooleanPropOrDefault(json, 'isRepeating', false),
      repetitionSchedule:
          getStringPropOrDefault(json, 'repetitionSchedule', null),
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
    if (requirePlanApproval != null) {
      map['requirePlanApproval'] = requirePlanApproval;
    }
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
    if (images != null) {
      map['images'] = images!.map((e) => e.toJson()).toList();
    }
    if (currentStep != null) map['currentStep'] = currentStep;
    if (totalSteps != null) map['totalSteps'] = totalSteps;
    if (currentAction != null) map['currentAction'] = currentAction;
    if (prStatus != null) map['prStatus'] = prStatus;
    if (scheduledTime != null) map['scheduledTime'] = scheduledTime;
    if (isRepeating != null) map['isRepeating'] = isRepeating;
    if (repetitionSchedule != null) {
      map['repetitionSchedule'] = repetitionSchedule;
    }
    return map;
  }

  Session copyWith({
    String? name,
    String? id,
    String? prompt,
    SourceContext? sourceContext,
    String? title,
    bool? requirePlanApproval,
    AutomationMode? automationMode,
    String? createTime,
    String? updateTime,
    SessionState? state,
    String? url,
    List<SessionOutput>? outputs,
    List<Media>? images,
    int? currentStep,
    int? totalSteps,
    String? currentAction,
    String? prStatus,
    String? scheduledTime,
    bool? isRepeating,
    String? repetitionSchedule,
  }) {
    return Session(
      name: name ?? this.name,
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      sourceContext: sourceContext ?? this.sourceContext,
      title: title ?? this.title,
      requirePlanApproval: requirePlanApproval ?? this.requirePlanApproval,
      automationMode: automationMode ?? this.automationMode,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      state: state ?? this.state,
      url: url ?? this.url,
      outputs: outputs ?? this.outputs,
      images: images ?? this.images,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      currentAction: currentAction ?? this.currentAction,
      prStatus: prStatus ?? this.prStatus,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isRepeating: isRepeating ?? this.isRepeating,
      repetitionSchedule: repetitionSchedule ?? this.repetitionSchedule,
    );
  }
}

T? getEnumPropOrDefault<T>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
  T? defaultValue,
) {
  if (json[key] == null) {
    return defaultValue;
  }
  return values.firstWhere(
    (e) => e.toString().split('.').last == json[key],
    orElse: () => defaultValue as T,
  );
}

class ListSessionsResponse {
  final List<Session> sessions;
  final String? nextPageToken;

  ListSessionsResponse({required this.sessions, this.nextPageToken});

  factory ListSessionsResponse.fromJson(Map<String, dynamic> json) {
    return ListSessionsResponse(
      sessions: getObjectArrayPropOrDefaultFunction(
        json,
        'sessions',
        Session.fromJson,
        () => <Session>[],
      ),
      nextPageToken: getStringPropOrDefault(json, 'nextPageToken', null),
    );
  }
}
