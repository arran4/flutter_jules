import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/ui/widgets/new_session_dialog.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockJulesClient extends Mock implements JulesClient {}

class MockAuthProvider extends Mock implements AuthProvider {
  final JulesClient _client;
  MockAuthProvider(this._client);
  @override
  JulesClient get client => _client;
  @override
  String? get token => 'token';
}

class MockSourceProvider extends Mock implements SourceProvider {
  List<CachedItem<Source>> _items = [];
  @override
  List<CachedItem<Source>> get items => _items;
  set items(List<CachedItem<Source>> value) => _items = value;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  DateTime? get lastFetchTime => DateTime.now();

  @override
  Future<void> fetchSources(
    JulesClient client, {
    bool force = false,
    String? authToken,
    GithubProvider? githubProvider,
    void Function(int total)? onProgress,
    SessionProvider? sessionProvider,
  }) async {}
}

class MockSessionProvider extends Mock implements SessionProvider {}

class MockGithubProvider extends Mock implements GithubProvider {}

class MockSettingsProvider extends Mock implements SettingsProvider {
  @override
  bool get hideArchivedAndReadOnly => true;
  @override
  List<SourceGroup> get sourceGroups => [];
}

class MockMessageQueueProvider extends Mock implements MessageQueueProvider {
  @override
  List<QueuedMessage> get queue => [];
}

void main() {
  late MockJulesClient mockClient;
  late MockAuthProvider mockAuth;
  late MockSourceProvider mockSource;
  late MockSessionProvider mockSession;
  late MockGithubProvider mockGithub;
  late MockSettingsProvider mockSettings;
  late MockMessageQueueProvider mockQueue;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockJulesClient();
    mockAuth = MockAuthProvider(mockClient);
    mockSource = MockSourceProvider();
    mockSession = MockSessionProvider();
    mockGithub = MockGithubProvider();
    mockSettings = MockSettingsProvider();
    mockQueue = MockMessageQueueProvider();

    // Add a dummy source
    mockSource.items = [
      CachedItem(
        Source(
          name: 'sources/test',
          id: '1',
          githubRepo: GitHubRepo(
            owner: 'owner',
            repo: 'repo',
            isPrivate: false,
            defaultBranch: GitHubBranch(displayName: 'main')
          )
        ),
        CacheMetadata(firstSeen: DateTime.now(), lastRetrieved: DateTime.now())
      )
    ];
  });

  testWidgets('Ctrl + Enter sends (default behavior)', (WidgetTester tester) async {
    NewSessionResult? result;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<SourceProvider>.value(value: mockSource),
          ChangeNotifierProvider<SessionProvider>.value(value: mockSession),
          ChangeNotifierProvider<GithubProvider>.value(value: mockGithub),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettings),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: mockQueue),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<NewSessionResult>(
                      context: context,
                      builder: (_) => const NewSessionDialog(),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Ensure source is selected
    expect(find.widgetWithText(TextField, 'owner/repo'), findsOneWidget);

    // Enter prompt
    await tester.enterText(find.widgetWithText(TextField, 'Prompt'), 'Test Prompt');
    await tester.pump();

    // Send using Ctrl+Enter
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.openNewDialog, isFalse);
    expect(result!.sessions.first.prompt, 'Test Prompt');
  });

  testWidgets('Meta + Enter sends (NEW)', (WidgetTester tester) async {
    NewSessionResult? result;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<SourceProvider>.value(value: mockSource),
          ChangeNotifierProvider<SessionProvider>.value(value: mockSession),
          ChangeNotifierProvider<GithubProvider>.value(value: mockGithub),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettings),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: mockQueue),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<NewSessionResult>(
                      context: context,
                      builder: (_) => const NewSessionDialog(),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Ensure source is selected
    expect(find.widgetWithText(TextField, 'owner/repo'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Prompt'), 'Test Prompt');
    await tester.pump();

    // Send using Meta+Enter
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);

    await tester.pumpAndSettle();

    expect(result, isNotNull, reason: 'Dialog should have closed with result');
    expect(result!.openNewDialog, isFalse);
  });

  testWidgets('Shift + Ctrl + Enter sends and new (NEW)', (WidgetTester tester) async {
    NewSessionResult? result;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<SourceProvider>.value(value: mockSource),
          ChangeNotifierProvider<SessionProvider>.value(value: mockSession),
          ChangeNotifierProvider<GithubProvider>.value(value: mockGithub),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettings),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: mockQueue),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog<NewSessionResult>(
                      context: context,
                      builder: (_) => const NewSessionDialog(),
                    );
                  },
                  child: const Text('Show Dialog'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Ensure source is selected
    expect(find.widgetWithText(TextField, 'owner/repo'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Prompt'), 'Test Prompt');
    await tester.pump();

    // Send using Shift+Ctrl+Enter
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);

    await tester.pumpAndSettle();

    // Should FAIL before implementation
    expect(result, isNotNull, reason: 'Dialog should have closed with result');
    expect(result!.openNewDialog, isTrue);
  });
}
