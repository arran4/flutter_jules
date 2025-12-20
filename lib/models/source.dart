import 'package:dartobjectutils/dartobjectutils.dart';

class GitHubRepoContext {
  final String startingBranch;

  GitHubRepoContext({required this.startingBranch});

  factory GitHubRepoContext.fromJson(Map<String, dynamic> json) {
    return GitHubRepoContext(
      startingBranch: getStringPropOrThrow(json, 'startingBranch'),
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
      source: getStringPropOrThrow(json, 'source'),
      githubRepoContext: getObjectFunctionPropOrDefault(json, 'githubRepoContext', GitHubRepoContext.fromJson, null),
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

class GitHubBranch {
  final String displayName;

  GitHubBranch({required this.displayName});

  factory GitHubBranch.fromJson(Map<String, dynamic> json) {
    return GitHubBranch(
      displayName: getStringPropOrThrow(json, 'displayName'),
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
      owner: getStringPropOrThrow(json, 'owner'),
      repo: getStringPropOrThrow(json, 'repo'),
      isPrivate: getBooleanPropOrThrow(json, 'isPrivate'),
      defaultBranch: getObjectFunctionPropOrDefault(json, 'defaultBranch', GitHubBranch.fromJson, null),
      branches: getObjectArrayPropOrDefaultFunction(json, 'branches', GitHubBranch.fromJson, () => null),
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
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      githubRepo: getObjectFunctionPropOrDefault(json, 'githubRepo', GitHubRepo.fromJson, null),
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
