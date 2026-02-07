import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/ui/widgets/new_session_dialog.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/prompt_template_provider.dart';
import 'package:flutter_jules/services/shortcut_registry.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  JulesClient get client => MockJulesClient();
  @override
  String? get token => 'token';
}

class MockJulesClient extends Mock implements JulesClient {}

class MockSourceProvider extends ChangeNotifier implements SourceProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  List<CachedItem<Source>> _items = [];

  @override
  List<CachedItem<Source>> get items => _items;

  set items(List<CachedItem<Source>> value) {
    _items = value;
    notifyListeners();
  }

  @override
  bool get isLoading => false;

  @override
  String get loadingStatus => '';

  @override
  String? get error => null;

  @override
  int get pendingGithubRefreshes => 0;

  @override
  DateTime? get lastFetchTime => DateTime.now();

  @override
  Future<void> fetchSources(
    JulesClient? client, {
    bool force = false,
    String? authToken,
    GithubProvider? githubProvider,
    void Function(int, String)? onProgress,
  }) async {}

  @override
  Future<void> refreshSource(
    JulesClient client,
    Source source, {
    String? authToken,
    GithubProvider? githubProvider,
  }) async {}
}

class MockGithubProvider extends ChangeNotifier implements GithubProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  // @override
  JulesClient? get client => MockJulesClient();

  // @override
  bool get isOffline => false;
}

class MockSessionProvider extends ChangeNotifier implements SessionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  List<CachedItem<Session>> get items => [];
}

class MockSettingsProvider extends ChangeNotifier implements SettingsProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get hideArchivedAndReadOnly => false;
  @override
  List<SourceGroup> get sourceGroups => [];
}

class MockMessageQueueProvider extends ChangeNotifier implements MessageQueueProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  List<QueuedMessage> get queue => [];

  @override
  bool get isOffline => false;

  @override
  List<QueuedMessage> getDrafts(String? sessionId) => [];
}

class MockPromptTemplateProvider extends ChangeNotifier implements PromptTemplateProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> addRecentPrompt(String prompt) async {}
}

class MockShortcutRegistry extends ChangeNotifier implements ShortcutRegistry {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void register(Shortcut shortcut) {}
  @override
  void unregister(Shortcut shortcut) {}
  @override
  Stream<AppShortcutAction> get onAction => const Stream.empty();
}

void main() {
  late MockSourceProvider mockSourceProvider;
  late MockSettingsProvider mockSettingsProvider;

  setUp(() {
    mockSourceProvider = MockSourceProvider();
    mockSettingsProvider = MockSettingsProvider();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NewSessionDialog branch selection logic', (WidgetTester tester) async {
    // Set screen size to avoid overflow
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;

    final meta = CacheMetadata(firstSeen: DateTime.now(), lastRetrieved: DateTime.now());

    // 1. Setup Source with NO branches
    final sourceNoBranches = Source(
      id: 'source-1',
      name: 'source-no-branches',
      githubRepo: GitHubRepo(
        owner: 'owner',
        repo: 'repo1',
        isPrivate: false,
        branches: [], // No branches
        defaultBranch: null,
      ),
    );

    // 2. Setup Source with branches but NO default
    final sourceWithBranchesNoDefault = Source(
      id: 'source-2',
      name: 'source-branches-no-default',
      githubRepo: GitHubRepo(
        owner: 'owner',
        repo: 'repo2',
        isPrivate: false,
        branches: [
          GitHubBranch(displayName: 'feature-1'),
          GitHubBranch(displayName: 'feature-2'),
        ],
        defaultBranch: null,
      ),
    );

     // 3. Setup Source with branches AND default
    final sourceWithDefault = Source(
      id: 'source-3',
      name: 'source-default',
      githubRepo: GitHubRepo(
        owner: 'owner',
        repo: 'repo3',
        isPrivate: false,
        branches: [
           GitHubBranch(displayName: 'main'),
           GitHubBranch(displayName: 'dev'),
        ],
        defaultBranch: GitHubBranch(displayName: 'main'),
      ),
    );

    mockSourceProvider.items = [
      CachedItem(sourceNoBranches, meta),
      CachedItem(sourceWithBranchesNoDefault, meta),
      CachedItem(sourceWithDefault, meta),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProvider()),
          ChangeNotifierProvider<SourceProvider>.value(value: mockSourceProvider),
          ChangeNotifierProvider<GithubProvider>.value(value: MockGithubProvider()),
          ChangeNotifierProvider<SessionProvider>.value(value: MockSessionProvider()),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: MockMessageQueueProvider()),
          ChangeNotifierProvider<PromptTemplateProvider>.value(value: MockPromptTemplateProvider()),
          ChangeNotifierProvider<ShortcutRegistry>.value(value: MockShortcutRegistry()),
        ],
        child: const MaterialApp(
          home: NewSessionDialog(),
        ),
      ),
    );

    // Wait for async init
    await tester.pumpAndSettle();

    // Select source with NO branches (repo1)
    await tester.enterText(find.widgetWithText(TextField, 'Repository'), 'repo1');
    await tester.pumpAndSettle();

    // Tap the item in overlay
    await tester.tap(find.text('owner/repo1'));
    await tester.pumpAndSettle();

    // Verify branch is empty (Currently it defaults to 'main', so this expects failure)
    final branchField = find.widgetWithText(TextField, 'Branch');
    final controller = (tester.widget(branchField) as TextField).controller;

    // Expectation 1: If no default branch (and no branches), it should be empty.
    expect(controller!.text, isEmpty, reason: "Branch should be empty for source with no branches");

    // Expectation 2: It should show suggestions 'main', 'master' if no branches.
    // Trigger suggestions
    await tester.tap(branchField);
    await tester.pumpAndSettle();
    expect(find.text('main'), findsOneWidget, reason: "Should suggest main");
    expect(find.text('master'), findsOneWidget, reason: "Should suggest master");


    // Now select source with branches but NO default (repo2)
    await tester.enterText(find.widgetWithText(TextField, 'Repository'), 'repo2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('owner/repo2'));
    await tester.pumpAndSettle();

    // Expectation 3: Branch should be empty (no default branch).
    expect(controller.text, isEmpty, reason: "Branch should be empty for source with branches but no default");


    // Now select source WITH default (repo3)
    await tester.enterText(find.widgetWithText(TextField, 'Repository'), 'repo3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('owner/repo3'));
    await tester.pumpAndSettle();

    // Expectation 4: Branch should be 'main'
    expect(controller.text, 'main', reason: "Branch should be main for source with default branch");
  });
}
