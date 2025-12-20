import 'package:dartobjectutils/dartobjectutils.dart';

class PlanStep {
  final String id;
  final String title;
  final String description;
  final int index;

  PlanStep({
    required this.id,
    required this.title,
    required this.description,
    required this.index,
  });

  factory PlanStep.fromJson(Map<String, dynamic> json) {
    return PlanStep(
      id: getStringPropOrThrow(json, 'id'),
      title: getStringPropOrThrow(json, 'title'),
      description: getStringPropOrThrow(json, 'description'),
      index: getNumberPropOrThrow(json, 'index')!.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'index': index,
      };
}

class Plan {
  final String id;
  final List<PlanStep> steps;
  final String createTime;

  Plan({
    required this.id,
    required this.steps,
    required this.createTime,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: getStringPropOrThrow(json, 'id'),
      steps: getObjectArrayPropOrDefaultFunction(json, 'steps', PlanStep.fromJson, () => <PlanStep>[]),
      createTime: getStringPropOrThrow(json, 'createTime'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'steps': steps.map((e) => e.toJson()).toList(),
        'createTime': createTime,
      };
}

class AgentMessaged {
  final String agentMessage;
  AgentMessaged({required this.agentMessage});
  factory AgentMessaged.fromJson(Map<String, dynamic> json) =>
      AgentMessaged(agentMessage: getStringPropOrThrow(json, 'agentMessage'));
  Map<String, dynamic> toJson() => {'agentMessage': agentMessage};
}

class UserMessaged {
  final String userMessage;
  UserMessaged({required this.userMessage});
  factory UserMessaged.fromJson(Map<String, dynamic> json) =>
      UserMessaged(userMessage: getStringPropOrThrow(json, 'userMessage'));
  Map<String, dynamic> toJson() => {'userMessage': userMessage};
}

class PlanGenerated {
  final Plan plan;
  PlanGenerated({required this.plan});
  factory PlanGenerated.fromJson(Map<String, dynamic> json) =>
      PlanGenerated(plan: getObjectFunctionPropOrThrow(json, 'plan', Plan.fromJson));
  Map<String, dynamic> toJson() => {'plan': plan.toJson()};
}

class PlanApproved {
  final String planId;
  PlanApproved({required this.planId});
  factory PlanApproved.fromJson(Map<String, dynamic> json) =>
      PlanApproved(planId: getStringPropOrThrow(json, 'planId'));
  Map<String, dynamic> toJson() => {'planId': planId};
}

class ProgressUpdated {
  final String title;
  final String description;
  ProgressUpdated({required this.title, required this.description});
  factory ProgressUpdated.fromJson(Map<String, dynamic> json) =>
      ProgressUpdated(
        title: getStringPropOrThrow(json, 'title'),
        description: getStringPropOrThrow(json, 'description'),
      );
  Map<String, dynamic> toJson() => {'title': title, 'description': description};
}

class SessionCompleted {
  SessionCompleted();
  factory SessionCompleted.fromJson(Map<String, dynamic> json) =>
      SessionCompleted();
  Map<String, dynamic> toJson() => {};
}

class SessionFailed {
  final String reason;
  SessionFailed({required this.reason});
  factory SessionFailed.fromJson(Map<String, dynamic> json) =>
      SessionFailed(reason: getStringPropOrThrow(json, 'reason'));
  Map<String, dynamic> toJson() => {'reason': reason};
}

class GitPatch {
  final String unidiffPatch;
  final String baseCommitId;
  final String suggestedCommitMessage;

  GitPatch({
    required this.unidiffPatch,
    required this.baseCommitId,
    required this.suggestedCommitMessage,
  });

  factory GitPatch.fromJson(Map<String, dynamic> json) {
    return GitPatch(
      unidiffPatch: getStringPropOrThrow(json, 'unidiffPatch'),
      baseCommitId: getStringPropOrThrow(json, 'baseCommitId'),
      suggestedCommitMessage: getStringPropOrThrow(json, 'suggestedCommitMessage'),
    );
  }

  Map<String, dynamic> toJson() => {
        'unidiffPatch': unidiffPatch,
        'baseCommitId': baseCommitId,
        'suggestedCommitMessage': suggestedCommitMessage,
      };
}

class ChangeSet {
  final String source;
  final GitPatch? gitPatch;

  ChangeSet({required this.source, this.gitPatch});

  factory ChangeSet.fromJson(Map<String, dynamic> json) {
    return ChangeSet(
      source: getStringPropOrThrow(json, 'source'),
      gitPatch: getObjectFunctionPropOrDefault(json, 'gitPatch', GitPatch.fromJson, null),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'source': source};
    if (gitPatch != null) map['gitPatch'] = gitPatch!.toJson();
    return map;
  }
}

class Media {
  final String data;
  final String mimeType;
  Media({required this.data, required this.mimeType});
  factory Media.fromJson(Map<String, dynamic> json) => Media(
        data: getStringPropOrThrow(json, 'data'),
        mimeType: getStringPropOrThrow(json, 'mimeType'),
      );
  Map<String, dynamic> toJson() => {'data': data, 'mimeType': mimeType};
}

class BashOutput {
  final String command;
  final String output;
  final int exitCode;
  BashOutput({
    required this.command,
    required this.output,
    required this.exitCode,
  });
  factory BashOutput.fromJson(Map<String, dynamic> json) => BashOutput(
        command: getStringPropOrThrow(json, 'command'),
        output: getStringPropOrThrow(json, 'output'),
        exitCode: getNumberPropOrThrow(json, 'exitCode')!.toInt(),
      );
  Map<String, dynamic> toJson() => {
        'command': command,
        'output': output,
        'exitCode': exitCode,
      };
}

class Artifact {
  final ChangeSet? changeSet;
  final Media? media;
  final BashOutput? bashOutput;

  Artifact({this.changeSet, this.media, this.bashOutput});

  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      changeSet: getObjectFunctionPropOrDefault(json, 'changeSet', ChangeSet.fromJson, null),
      media: getObjectFunctionPropOrDefault(json, 'media', Media.fromJson, null),
      bashOutput: getObjectFunctionPropOrDefault(json, 'bashOutput', BashOutput.fromJson, null),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (changeSet != null) map['changeSet'] = changeSet!.toJson();
    if (media != null) map['media'] = media!.toJson();
    if (bashOutput != null) map['bashOutput'] = bashOutput!.toJson();
    return map;
  }
}

class Activity {
  final String name;
  final String id;
  final String description;
  final String createTime;
  final String? originator;
  final List<Artifact>? artifacts;
  
  // Union fields
  final AgentMessaged? agentMessaged;
  final UserMessaged? userMessaged;
  final PlanGenerated? planGenerated;
  final PlanApproved? planApproved;
  final ProgressUpdated? progressUpdated;
  final SessionCompleted? sessionCompleted;
  final SessionFailed? sessionFailed;

  Activity({
    required this.name,
    required this.id,
    required this.description,
    required this.createTime,
    this.originator,
    this.artifacts,
    this.agentMessaged,
    this.userMessaged,
    this.planGenerated,
    this.planApproved,
    this.progressUpdated,
    this.sessionCompleted,
    this.sessionFailed,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      description: getStringPropOrThrow(json, 'description'),
      createTime: getStringPropOrThrow(json, 'createTime'),
      originator: getStringPropOrDefault(json, 'originator', null),
      artifacts: getObjectArrayPropOrDefaultFunction(json, 'artifacts', Artifact.fromJson, () => null),
      agentMessaged: getObjectFunctionPropOrDefault(json, 'agentMessaged', AgentMessaged.fromJson, null),
      userMessaged: getObjectFunctionPropOrDefault(json, 'userMessaged', UserMessaged.fromJson, null),
      planGenerated: getObjectFunctionPropOrDefault(json, 'planGenerated', PlanGenerated.fromJson, null),
      planApproved: getObjectFunctionPropOrDefault(json, 'planApproved', PlanApproved.fromJson, null),
      progressUpdated: getObjectFunctionPropOrDefault(json, 'progressUpdated', ProgressUpdated.fromJson, null),
      sessionCompleted: getObjectFunctionPropOrDefault(json, 'sessionCompleted', SessionCompleted.fromJson, null),
      sessionFailed: getObjectFunctionPropOrDefault(json, 'sessionFailed', SessionFailed.fromJson, null),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
      'description': description,
      'createTime': createTime,
    };
    if (originator != null) map['originator'] = originator;
    if (artifacts != null) {
      map['artifacts'] = artifacts!.map((e) => e.toJson()).toList();
    }
    if (agentMessaged != null) map['agentMessaged'] = agentMessaged!.toJson();
    if (userMessaged != null) map['userMessaged'] = userMessaged!.toJson();
    if (planGenerated != null) map['planGenerated'] = planGenerated!.toJson();
    if (planApproved != null) map['planApproved'] = planApproved!.toJson();
    if (progressUpdated != null) map['progressUpdated'] = progressUpdated!.toJson();
    if (sessionCompleted != null) map['sessionCompleted'] = sessionCompleted!.toJson();
    if (sessionFailed != null) map['sessionFailed'] = sessionFailed!.toJson();
    return map;
  }
}
