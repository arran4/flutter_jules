import 'package:dartobjectutils/dartobjectutils.dart';
import 'enums.dart';
import 'source.dart';
import 'media.dart';

class Metadata {
  final String key;
  final String value;
  final String updateTime;

  Metadata({
    required this.key,
    required this.value,
    required this.updateTime,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      key: getStringPropOrThrow(json, 'key'),
      value: getStringPropOrThrow(json, 'value'),
      updateTime: getStringPropOrThrow(json, 'updateTime'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'updateTime': updateTime,
    };
  }
}

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
  final SourceContext? sourceContext;
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
  final String? ciStatus;
  final String? mergeableState;
  final int? additions;
  final int? deletions;
  final int? changedFiles;
  final String? diffUrl;
  final String? patchUrl;
  final List<Metadata> metadata;

  Session({
    required this.name,
    required this.id,
    required this.prompt,
    this.sourceContext,
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
    this.ciStatus,
    this.mergeableState,
    this.additions,
    this.deletions,
    this.changedFiles,
    this.diffUrl,
    this.patchUrl,
    this.metadata = const [],
  });

  List<String> get tags {
    try {
      final meta = metadata.firstWhere((m) => m.key == 'tags');
      return meta.value.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  String? get notes {
    try {
      final meta = metadata.firstWhere((m) => m.key == 'notes');
      return meta.value;
    } catch (e) {
      return null;
    }
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      prompt: getStringPropOrThrow(json, 'prompt'),
      sourceContext: getObjectFunctionPropOrDefault(
        json,
        'sourceContext',
        SourceContext.fromJson,
        null,
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
      ciStatus: getStringPropOrDefault(json, 'ciStatus', null),
      mergeableState: getStringPropOrDefault(json, 'mergeableState', null),
      additions: getNumberPropOrDefault<num?>(json, 'additions', null)?.toInt(),
      deletions: getNumberPropOrDefault<num?>(json, 'deletions', null)?.toInt(),
      changedFiles:
          getNumberPropOrDefault<num?>(json, 'changedFiles', null)?.toInt(),
      diffUrl: getStringPropOrDefault(json, 'diffUrl', null),
      patchUrl: getStringPropOrDefault(json, 'patchUrl', null),
      metadata: getObjectArrayPropOrDefaultFunction(
        json,
        'metadata',
        Metadata.fromJson,
        () => [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
      'prompt': prompt,
    };
    if (sourceContext != null) {
      map['sourceContext'] = sourceContext!.toJson();
    }
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
    if (ciStatus != null) map['ciStatus'] = ciStatus;
    if (mergeableState != null) map['mergeableState'] = mergeableState;
    if (additions != null) map['additions'] = additions;
    if (deletions != null) map['deletions'] = deletions;
    if (changedFiles != null) map['changedFiles'] = changedFiles;
    if (diffUrl != null) map['diffUrl'] = diffUrl;
    if (patchUrl != null) map['patchUrl'] = patchUrl;
    if (metadata.isNotEmpty) {
      map['metadata'] = metadata.map((e) => e.toJson()).toList();
    }
    return map;
  }

  Session copyWith({
    String? name,
    String? id,
    String? prompt,
    SourceContext? sourceContext,
    bool? sourceContextIsNull,
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
    String? ciStatus,
    String? mergeableState,
    int? additions,
    int? deletions,
    int? changedFiles,
    String? diffUrl,
    String? patchUrl,
    List<Metadata>? metadata,
  }) {
    return Session(
      name: name ?? this.name,
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      sourceContext: sourceContextIsNull == true
          ? null
          : sourceContext ?? this.sourceContext,
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
      ciStatus: ciStatus ?? this.ciStatus,
      mergeableState: mergeableState ?? this.mergeableState,
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
      changedFiles: changedFiles ?? this.changedFiles,
      diffUrl: diffUrl ?? this.diffUrl,
      patchUrl: patchUrl ?? this.patchUrl,
      metadata: metadata ?? this.metadata,
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
