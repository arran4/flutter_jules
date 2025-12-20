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
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      index: json['index'] as int,
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
      id: json['id'] as String,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => PlanStep.fromJson(e))
              .toList() ??
          [],
      createTime: json['createTime'] as String,
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
      AgentMessaged(agentMessage: json['agentMessage'] as String);
  Map<String, dynamic> toJson() => {'agentMessage': agentMessage};
}

class UserMessaged {
  final String userMessage;
  UserMessaged({required this.userMessage});
  factory UserMessaged.fromJson(Map<String, dynamic> json) =>
      UserMessaged(userMessage: json['userMessage'] as String);
  Map<String, dynamic> toJson() => {'userMessage': userMessage};
}

class PlanGenerated {
  final Plan plan;
  PlanGenerated({required this.plan});
  factory PlanGenerated.fromJson(Map<String, dynamic> json) =>
      PlanGenerated(plan: Plan.fromJson(json['plan']));
  Map<String, dynamic> toJson() => {'plan': plan.toJson()};
}

class PlanApproved {
  final String planId;
  PlanApproved({required this.planId});
  factory PlanApproved.fromJson(Map<String, dynamic> json) =>
      PlanApproved(planId: json['planId'] as String);
  Map<String, dynamic> toJson() => {'planId': planId};
}

class ProgressUpdated {
  final String title;
  final String description;
  ProgressUpdated({required this.title, required this.description});
  factory ProgressUpdated.fromJson(Map<String, dynamic> json) =>
      ProgressUpdated(
        title: json['title'] as String,
        description: json['description'] as String,
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
      SessionFailed(reason: json['reason'] as String);
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
      unidiffPatch: json['unidiffPatch'] as String,
      baseCommitId: json['baseCommitId'] as String,
      suggestedCommitMessage: json['suggestedCommitMessage'] as String,
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
      source: json['source'] as String,
      gitPatch: json['gitPatch'] != null
          ? GitPatch.fromJson(json['gitPatch'])
          : null,
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
        data: json['data'] as String,
        mimeType: json['mimeType'] as String,
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
        command: json['command'] as String,
        output: json['output'] as String,
        exitCode: json['exitCode'] as int,
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
      changeSet: json['changeSet'] != null
          ? ChangeSet.fromJson(json['changeSet'])
          : null,
      media: json['media'] != null ? Media.fromJson(json['media']) : null,
      bashOutput: json['bashOutput'] != null
          ? BashOutput.fromJson(json['bashOutput'])
          : null,
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
      name: json['name'] as String,
      id: json['id'] as String,
      description: json['description'] as String,
      createTime: json['createTime'] as String,
      originator: json['originator'] as String?,
      artifacts: (json['artifacts'] as List<dynamic>?)
          ?.map((e) => Artifact.fromJson(e))
          .toList(),
      agentMessaged: json['agentMessaged'] != null
          ? AgentMessaged.fromJson(json['agentMessaged'])
          : null,
      userMessaged: json['userMessaged'] != null
          ? UserMessaged.fromJson(json['userMessaged'])
          : null,
      planGenerated: json['planGenerated'] != null
          ? PlanGenerated.fromJson(json['planGenerated'])
          : null,
      planApproved: json['planApproved'] != null
          ? PlanApproved.fromJson(json['planApproved'])
          : null,
      progressUpdated: json['progressUpdated'] != null
          ? ProgressUpdated.fromJson(json['progressUpdated'])
          : null,
      sessionCompleted: json['sessionCompleted'] != null
          ? SessionCompleted.fromJson(json['sessionCompleted'])
          : null,
      sessionFailed: json['sessionFailed'] != null
          ? SessionFailed.fromJson(json['sessionFailed'])
          : null,
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
