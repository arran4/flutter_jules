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
