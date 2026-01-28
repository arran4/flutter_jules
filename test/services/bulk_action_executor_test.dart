import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/services/bulk_action_executor.dart';
import 'package:flutter_jules/models/bulk_action.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/github_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/models.dart';

// Fakes
class FakeSessionProvider extends Fake implements SessionProvider {
  List<CachedItem<Session>> _items = [];
  int markAsReadCalls = 0;
  int markAsUnreadCalls = 0;

  @override
  List<CachedItem<Session>> get items => _items;

  void setItems(List<Session> sessions) {
    _items = sessions.map((s) => CachedItem(
      s,
      CacheMetadata(
        firstSeen: DateTime.now(),
        lastRetrieved: DateTime.now(),
      ),
    )).toList();
  }

  @override
  Future<void> markAsRead(String? sessionId, String? authToken) async {
    markAsReadCalls++;
  }

  @override
  Future<void> markAsUnread(String? sessionId, String? authToken) async {
    markAsUnreadCalls++;
  }
}

class FakeJulesClient extends Fake implements JulesClient {}

class FakeAuthProvider extends Fake implements AuthProvider {
  @override
  String? get token => 'test-token';
}

class FakeGithubProvider extends Fake implements GithubProvider {}

class FakeSettingsProvider extends Fake implements SettingsProvider {
    @override
    bool get useCorpJulesUrl => false;
}

void main() {
  late BulkActionExecutor executor;
  late FakeSessionProvider sessionProvider;
  late FakeJulesClient julesClient;
  late FakeAuthProvider authProvider;
  late FakeGithubProvider githubProvider;
  late FakeSettingsProvider settingsProvider;

  setUp(() {
    sessionProvider = FakeSessionProvider();
    julesClient = FakeJulesClient();
    authProvider = FakeAuthProvider();
    githubProvider = FakeGithubProvider();
    settingsProvider = FakeSettingsProvider();

    executor = BulkActionExecutor(
      sessionProvider: sessionProvider,
      julesClient: julesClient,
      authProvider: authProvider,
      githubProvider: githubProvider,
      settingsProvider: settingsProvider,
    );
  });

  test('undoLogEntry should undo action and update log state', () async {
    final session = Session(
      id: 's1',
      name: 'Session 1',
      prompt: 'prompt',
      state: SessionState.STATE_UNSPECIFIED,
    );
    sessionProvider.setItems([session]);

    final config = BulkJobConfig(
      targetType: BulkTargetType.visible,
      sorts: [],
      actions: [
        BulkActionStep(type: BulkActionType.markAsRead),
      ],
    );

    executor.startJob(config, [session]);

    while (executor.status == BulkJobStatus.running) {
      await Future.delayed(Duration(milliseconds: 10));
    }

    expect(executor.logs.length, greaterThan(0));
    final logIndex = executor.logs.indexWhere((l) => l.undoActionType == BulkActionType.markAsUnread);
    expect(logIndex, isNot(-1));
    final logEntry = executor.logs[logIndex];
    expect(logEntry.isUndone, false);

    await executor.undoLogEntry(logEntry);

    expect(sessionProvider.markAsUnreadCalls, 1);

    final updatedLog = executor.logs.firstWhere((l) => l.message == logEntry.message && l.timestamp == logEntry.timestamp);
    expect(updatedLog.isUndone, true);
  });

  test('undoAll should undo all undoable actions', () async {
    final session1 = Session(id: 's1', name: 'Session 1', prompt: '', state: SessionState.STATE_UNSPECIFIED);
    final session2 = Session(id: 's2', name: 'Session 2', prompt: '', state: SessionState.STATE_UNSPECIFIED);
    sessionProvider.setItems([session1, session2]);

    final config = BulkJobConfig(
      targetType: BulkTargetType.visible,
      sorts: [],
      actions: [
        BulkActionStep(type: BulkActionType.markAsRead),
      ],
      waitBetween: Duration.zero,
    );

    executor.startJob(config, [session1, session2]);

    while (executor.status == BulkJobStatus.running) {
      await Future.delayed(Duration(milliseconds: 10));
    }

    expect(sessionProvider.markAsReadCalls, 2);

    final undoableLogs = executor.logs.where((l) => l.undoActionType != null).toList();
    expect(undoableLogs.length, 2);

    await executor.undoAll();

    expect(sessionProvider.markAsUnreadCalls, 2);

    expect(executor.logs.where((l) => l.undoActionType != null && l.isUndone).length, 2);
  });

  test('undoLogEntry should do nothing if already undone', () async {
    final session = Session(id: 's1', name: 'Session 1', prompt: '', state: SessionState.STATE_UNSPECIFIED);
    sessionProvider.setItems([session]);

    final config = BulkJobConfig(
      targetType: BulkTargetType.visible,
      sorts: [],
      actions: [
        BulkActionStep(type: BulkActionType.markAsRead),
      ],
    );

    executor.startJob(config, [session]);
    while (executor.status == BulkJobStatus.running) {
      await Future.delayed(Duration(milliseconds: 10));
    }

    final logEntry = executor.logs.firstWhere((l) => l.undoActionType != null);

    await executor.undoLogEntry(logEntry);
    expect(sessionProvider.markAsUnreadCalls, 1);

    final updatedLog = executor.logs.firstWhere((l) => l.message == logEntry.message && l.timestamp == logEntry.timestamp);
    expect(updatedLog.isUndone, true);

    await executor.undoLogEntry(updatedLog);
    expect(sessionProvider.markAsUnreadCalls, 1);
  });
}
