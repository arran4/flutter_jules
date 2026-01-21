import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/ui/screens/session_detail_screen.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/services/timer_service.dart';
import 'package:flutter_jules/services/dev_mode_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';

// Mocks
class MockJulesClient extends Mock implements JulesClient {
  @override
  Future<void> sendMessage(String? sessionName, String? message) {
    return super.noSuchMethod(
      Invocation.method(#sendMessage, [sessionName, message]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }

  @override
  Future<Session> getSession(String? name) {
    return super.noSuchMethod(
      Invocation.method(#getSession, [name]),
      returnValue: Future.value(Session(id: '1', name: 'sessions/1', prompt: '')),
      returnValueForMissingStub: Future.value(Session(id: '1', name: 'sessions/1', prompt: '')),
    );
  }

  @override
  Future<List<Activity>> listActivities(String? session, {void Function(dynamic)? onDebug, void Function(int)? onProgress, bool Function(Session)? shouldStop}) {
     return super.noSuchMethod(
      Invocation.method(#listActivities, [session], {#onDebug: onDebug, #onProgress: onProgress, #shouldStop: shouldStop}),
      returnValue: Future.value(<Activity>[]),
      returnValueForMissingStub: Future.value(<Activity>[]),
    );
  }
}

class MockAuthProvider extends Mock implements AuthProvider {
  final JulesClient _client;
  MockAuthProvider(this._client);

  @override
  JulesClient get client => _client;

  @override
  String? get token => 'token';
}

class MockSessionProvider extends Mock implements SessionProvider {
  @override
  List<CachedItem<Session>> get items => [];

  @override
  Future<void> addPendingMessage(String? sessionId, String? content, String? authToken) {
      return super.noSuchMethod(
      Invocation.method(#addPendingMessage, [sessionId, content, authToken]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }

  @override
  Future<void> updateSession(Session? session, {String? authToken}) {
     return Future.value();
  }
}

class MockMessageQueueProvider extends Mock implements MessageQueueProvider {
  @override
  List<QueuedMessage> get queue => super.noSuchMethod(
        Invocation.getter(#queue),
        returnValue: <QueuedMessage>[],
        returnValueForMissingStub: <QueuedMessage>[],
      ) as List<QueuedMessage>;

  @override
  List<QueuedMessage> getDrafts(String? sessionId) => [];

  @override
  bool get isOffline => false;
}

class MockSettingsProvider extends Mock implements SettingsProvider {
  @override
  SessionRefreshPolicy get refreshOnOpen => SessionRefreshPolicy.none;

  @override
  SessionRefreshPolicy get refreshOnMessage => SessionRefreshPolicy.none;

  @override
  MessageSubmitAction get enterKeyAction => MessageSubmitAction.submitsMessage;

  @override
  EscKeyAction get escKeyAction => EscKeyAction.doesNothing;
}

class MockCacheService extends Mock implements CacheService {
  @override
  Future<CachedSessionDetails?> loadSessionDetails(String? token, String? sessionId) async => null;
}

class MockTimerService extends Mock implements TimerService {}

class MockDevModeProvider extends Mock implements DevModeProvider {
  @override
  bool get isDevMode => false;
}

void main() {
  late MockJulesClient mockClient;
  late MockAuthProvider mockAuth;
  late MockSessionProvider mockSession;
  late MockMessageQueueProvider mockQueue;
  late MockSettingsProvider mockSettings;
  late MockCacheService mockCache;
  late MockTimerService mockTimer;
  late MockDevModeProvider mockDevMode;

  setUp(() {
    mockClient = MockJulesClient();
    mockAuth = MockAuthProvider(mockClient);
    mockSession = MockSessionProvider();
    mockQueue = MockMessageQueueProvider();
    mockSettings = MockSettingsProvider();
    mockCache = MockCacheService();
    mockTimer = MockTimerService();
    mockDevMode = MockDevModeProvider();
  });

  testWidgets('Established session bypasses pending check and sends message', (WidgetTester tester) async {
    // 1. Setup Session
    final session = Session(
      id: '123',
      name: 'sessions/123', // Established format
      prompt: 'Test Prompt',
    );

    // 2. Setup Queue with matching prompt (simulate stuck creation)
    final queuedMsg = QueuedMessage(
      id: 'q1',
      sessionId: 'new_session',
      content: 'Test Prompt',
      createdAt: DateTime.now(),
      type: QueuedMessageType.sessionCreation,
      metadata: session.toJson(),
    );

    when(mockQueue.queue).thenReturn([queuedMsg]);
    when(mockQueue.isOffline).thenReturn(false);

    // 3. Pump Widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthProvider>.value(value: mockAuth),
          Provider<SessionProvider>.value(value: mockSession),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: mockQueue),
          Provider<SettingsProvider>.value(value: mockSettings),
          Provider<CacheService>.value(value: mockCache),
          Provider<TimerService>.value(value: mockTimer),
          Provider<DevModeProvider>.value(value: mockDevMode),
        ],
        child: MaterialApp(
          home: SessionDetailScreen(session: session),
        ),
      ),
    );

    // 4. Enter message and send
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // 5. Verify sendMessage was called
    verify(mockClient.sendMessage('sessions/123', 'Hello')).called(1);
  });

  testWidgets('Pending session respects pending check', (WidgetTester tester) async {
    // 1. Setup Session
    final session = Session(
      id: 'new_session',
      name: 'new_session', // Pending format
      prompt: 'Test Prompt',
    );

    // 2. Setup Queue with matching prompt
    final queuedMsg = QueuedMessage(
      id: 'q1',
      sessionId: 'new_session',
      content: 'Test Prompt',
      createdAt: DateTime.now(),
      type: QueuedMessageType.sessionCreation,
      metadata: session.toJson(),
    );

    when(mockQueue.queue).thenReturn([queuedMsg]);
    when(mockQueue.isOffline).thenReturn(false);

    // 3. Pump Widget
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthProvider>.value(value: mockAuth),
          Provider<SessionProvider>.value(value: mockSession),
          ChangeNotifierProvider<MessageQueueProvider>.value(value: mockQueue),
          Provider<SettingsProvider>.value(value: mockSettings),
          Provider<CacheService>.value(value: mockCache),
          Provider<TimerService>.value(value: mockTimer),
          Provider<DevModeProvider>.value(value: mockDevMode),
        ],
        child: MaterialApp(
          home: SessionDetailScreen(session: session),
        ),
      ),
    );

    // 4. Enter message and send
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(); // Handle async
    await tester.pump(const Duration(milliseconds: 100)); // Wait for async logic

    // 5. Verify sendMessage was NOT called
    verifyNever(mockClient.sendMessage(any, any));

    // 6. Verify Error SnackBar
    expect(find.textContaining("pending creation"), findsOneWidget);
  });
}
