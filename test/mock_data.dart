import 'package:jules_client/models.dart';
import 'package:jules_client/models/api_exchange.dart';

class MockData {
  static const String sessionId = 'sessions/1234567890';
  static const String sourceName = 'sources/mock-repo';

  static final Session mockSession = Session(
    id: sessionId,
    name: sessionId,
    title: 'Implement Screenshot Automation',
    prompt: 'Create a GitHub Action to generate screenshots automatically.',
    state: SessionState.IN_PROGRESS,
    createTime: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    updateTime: DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    sourceContext: SourceContext(source: sourceName, githubRepoContext: GitHubRepoContext(startingBranch: 'main')),
    currentStep: 3,
    totalSteps: 5,
    currentAction: 'Running integration tests...',
    images: [],
    outputs: [
      SessionOutput(
        pullRequest: PullRequest(
          url: 'https://github.com/example/repo/pull/42',
          title: 'feat: Add screenshot workflow',
          description: 'Adds automated screenshot generation.',
        ),
      ),
    ],
  );

  static final Session mockSession2 = Session(
    id: 'sessions/0987654321',
    name: 'sessions/0987654321',
    title: 'Fix Login Bug',
    prompt: 'Login button is disabled when password is valid.',
    state: SessionState.COMPLETED,
    createTime: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    updateTime: DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
    sourceContext: SourceContext(source: sourceName, githubRepoContext: GitHubRepoContext(startingBranch: 'fix-login')),
  );

  static final List<Session> mockSessions = [
    mockSession,
    mockSession2,
    Session(
      id: 'sessions/1122334455',
      name: 'sessions/1122334455',
      title: 'Explore Architecture',
      prompt: 'Explain the project structure.',
      state: SessionState.QUEUED,
      createTime: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      updateTime: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      sourceContext: SourceContext(source: sourceName, githubRepoContext: GitHubRepoContext(startingBranch: 'main')),
    ),
  ];

  static final List<Activity> mockActivities = [
    Activity(
      name: 'activities/1',
      id: 'activities/1',
      createTime: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      userMessaged: UserMessaged(userMessage: 'Create a GitHub Action to generate screenshots automatically.'),
    ),
    Activity(
      name: 'activities/2',
      id: 'activities/2',
      createTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 59)).toIso8601String(),
      agentMessaged: AgentMessaged(agentMessage: 'I can help with that. I will look at your existing workflows first.'),
    ),
    Activity(
      name: 'activities/3',
      id: 'activities/3',
      createTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 58)).toIso8601String(),
      artifacts: [
        Artifact(bashOutput: BashOutput(command: 'ls -F', output: 'README.md', exitCode: 0)),
      ],
    ),
    Activity(
      name: 'activities/4',
      id: 'activities/4',
      createTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)).toIso8601String(),
      agentMessaged: AgentMessaged(agentMessage: 'I see you are using Flutter. I will add an integration test and a workflow file.'),
    ),
  ];

  static final List<Source> mockSources = [
    Source(
      name: sourceName,
      id: sourceName,
      githubRepo: GitHubRepo(owner: 'owner', repo: 'repo', isPrivate: true),
    ),
    Source(
      name: 'sources/legacy-code',
      id: 'sources/legacy-code',
      githubRepo: GitHubRepo(owner: 'owner', repo: 'legacy', isPrivate: false),
    ),
  ];
}
