
enum AutomationMode {
  AUTOMATION_MODE_UNSPECIFIED,
  AUTO_CREATE_PR,
}

enum SessionState {
  STATE_UNSPECIFIED,
  QUEUED,
  PLANNING,
  AWAITING_PLAN_APPROVAL,
  AWAITING_USER_FEEDBACK,
  IN_PROGRESS,
  PAUSED,
  FAILED,
  COMPLETED,
}

// --- GitHub Contexts (for Session creation) ---

class GitHubRepoContext {
  final String startingBranch;

  GitHubRepoContext({required this.startingBranch});

  factory GitHubRepoContext.fromJson(Map<String, dynamic> json) {
    return GitHubRepoContext(
      startingBranch: json['startingBranch'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startingBranch': startingBranch,
    };
  }
}

class SourceContext {
  final String source;
  final GitHubRepoContext? githubRepoContext;

  SourceContext({
    required this.source,
    this.githubRepoContext,
  });

  factory SourceContext.fromJson(Map<String, dynamic> json) {
    return SourceContext(
      source: json['source'] as String,
      githubRepoContext: json['githubRepoContext'] != null
          ? GitHubRepoContext.fromJson(json['githubRepoContext'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'source': source,
    };
    if (githubRepoContext != null) {
      map['githubRepoContext'] = githubRepoContext!.toJson();
    }
    return map;
  }
}

// --- Sources Resource ---

class GitHubBranch {
  final String displayName;

  GitHubBranch({required this.displayName});

  factory GitHubBranch.fromJson(Map<String, dynamic> json) {
    return GitHubBranch(
      displayName: json['displayName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'displayName': displayName};
}

class GitHubRepo {
  final String owner;
  final String repo;
  final bool isPrivate;
  final GitHubBranch? defaultBranch;
  final List<GitHubBranch>? branches;

  GitHubRepo({
    required this.owner,
    required this.repo,
    required this.isPrivate,
    this.defaultBranch,
    this.branches,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      isPrivate: json['isPrivate'] as bool,
      defaultBranch: json['defaultBranch'] != null
          ? GitHubBranch.fromJson(json['defaultBranch'])
          : null,
      branches: (json['branches'] as List<dynamic>?)
          ?.map((e) => GitHubBranch.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'owner': owner,
      'repo': repo,
      'isPrivate': isPrivate,
    };
    if (defaultBranch != null) {
      map['defaultBranch'] = defaultBranch!.toJson();
    }
    if (branches != null) {
      map['branches'] = branches!.map((e) => e.toJson()).toList();
    }
    return map;
  }
}

class Source {
  final String name;
  final String id;
  final GitHubRepo? githubRepo;

  Source({
    required this.name,
    required this.id,
    this.githubRepo,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      name: json['name'] as String,
      id: json['id'] as String,
      githubRepo: json['githubRepo'] != null
          ? GitHubRepo.fromJson(json['githubRepo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
    };
    if (githubRepo != null) {
      map['githubRepo'] = githubRepo!.toJson();
    }
    return map;
  }
}


// --- Activities Resource ---

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

// Artifacts

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

// --- Session (Original) ---

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
