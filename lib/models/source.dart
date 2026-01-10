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
    return {'startingBranch': startingBranch};
  }
}

class SourceContext {
  final String source;
  final GitHubRepoContext? githubRepoContext;

  SourceContext({required this.source, this.githubRepoContext});

  factory SourceContext.fromJson(Map<String, dynamic> json) {
    return SourceContext(
      source: getStringPropOrThrow(json, 'source'),
      githubRepoContext: getObjectFunctionPropOrDefault(
        json,
        'githubRepoContext',
        GitHubRepoContext.fromJson,
        null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'source': source};
    if (githubRepoContext != null) {
      map['githubRepoContext'] = githubRepoContext!.toJson();
    }
    return map;
  }
}

class ListSourcesResponse {
  final List<Source> sources;
  final String? nextPageToken;

  ListSourcesResponse({required this.sources, this.nextPageToken});

  factory ListSourcesResponse.fromJson(Map<String, dynamic> json) {
    return ListSourcesResponse(
      sources: getObjectArrayPropOrDefaultFunction(
        json,
        'sources',
        Source.fromJson,
        () => <Source>[],
      ),
      nextPageToken: getStringPropOrDefault(json, 'nextPageToken', null),
    );
  }
}

class GitHubBranch {
  final String displayName;

  GitHubBranch({required this.displayName});

  factory GitHubBranch.fromJson(Map<String, dynamic> json) {
    return GitHubBranch(displayName: getStringPropOrThrow(json, 'displayName'));
  }

  Map<String, dynamic> toJson() => {'displayName': displayName};
}

class GitHubRepo {
  final String owner;
  final String repo;
  final bool isPrivate;
  final GitHubBranch? defaultBranch;
  final List<GitHubBranch>? branches;
  final String? repoName;
  final int? repoId;
  final bool? isPrivateGh;
  final String? description;
  final String? primaryLanguage;
  final String? license;
  final int? openIssuesCount;
  final bool? isFork;

  GitHubRepo({
    required this.owner,
    required this.repo,
    required this.isPrivate,
    this.defaultBranch,
    this.branches,
    this.repoName,
    this.repoId,
    this.isPrivateGh,
    this.description,
    this.primaryLanguage,
    this.license,
    this.openIssuesCount,
    this.isFork,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      owner: getStringPropOrThrow(json, 'owner'),
      repo: getStringPropOrThrow(json, 'repo'),
      isPrivate: getBooleanPropOrThrow(json, 'isPrivate'),
      defaultBranch: getObjectFunctionPropOrDefault(
        json,
        'defaultBranch',
        GitHubBranch.fromJson,
        null,
      ),
      branches: getObjectArrayPropOrDefaultFunction(
        json,
        'branches',
        GitHubBranch.fromJson,
        () => null,
      ),
      repoName: getStringPropOrDefault(json, 'repoName', null),
      repoId: getIntPropOrDefault(json, 'repoId', null),
      isPrivateGh: getBooleanPropOrDefault(json, 'isPrivateGh', null),
      description: getStringPropOrDefault(json, 'description', null),
      primaryLanguage: getStringPropOrDefault(json, 'primaryLanguage', null),
      license: getStringPropOrDefault(json, 'license', null),
      openIssuesCount: getIntPropOrDefault(json, 'openIssuesCount', null),
      isFork: getBooleanPropOrDefault(json, 'isFork', null),
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
    if (repoName != null) map['repoName'] = repoName;
    if (repoId != null) map['repoId'] = repoId;
    if (isPrivateGh != null) map['isPrivateGh'] = isPrivateGh;
    if (description != null) map['description'] = description;
    if (primaryLanguage != null) map['primaryLanguage'] = primaryLanguage;
    if (license != null) map['license'] = license;
    if (openIssuesCount != null) map['openIssuesCount'] = openIssuesCount;
    if (isFork != null) map['isFork'] = isFork;
    return map;
  }
}

class Source {
  final String name;
  final String id;
  final GitHubRepo? githubRepo;

  Source({required this.name, required this.id, this.githubRepo});

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      name: getStringPropOrThrow(json, 'name'),
      id: getStringPropOrThrow(json, 'id'),
      githubRepo: getObjectFunctionPropOrDefault(
        json,
        'githubRepo',
        GitHubRepo.fromJson,
        null,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'name': name, 'id': id};
    if (githubRepo != null) {
      map['githubRepo'] = githubRepo!.toJson();
    }
    return map;
  }
}
