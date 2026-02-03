import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/unread_rule.dart';
import 'package:flutter_jules/models/enums.dart';

// Manual Mocks
class MockSettingsProvider extends Mock implements SettingsProvider {
  @override
  List<UnreadRule> unreadRules = [];
}

class MockCacheService extends Mock implements CacheService {
  @override
  Future<void> saveSessions(
      String? authToken, List<CachedItem<Session>>? sessions) async {}

  @override
  Future<void> markSessionAsRead(String? authToken, String? sessionId) async {}
}

void main() {
  group('SessionProvider Unread Logic', () {
    late SessionProvider sessionProvider;
    late MockSettingsProvider mockSettingsProvider;
    late MockCacheService mockCacheService;

    setUp(() {
      sessionProvider = SessionProvider();
      mockSettingsProvider = MockSettingsProvider();
      mockCacheService = MockCacheService();

      sessionProvider.setSettingsProvider(mockSettingsProvider);
      sessionProvider.setCacheService(mockCacheService);
    });

    Session createSession({
      String id = '1',
      String state = 'IN_PROGRESS',
      int step = 1,
      String action = 'thinking',
    }) {
      return Session(
        id: id,
        name: 'sessions/$id',
        prompt: 'test prompt',
        state: SessionState.values.firstWhere(
            (e) => e.toString().split('.').last == state,
            orElse: () => SessionState.IN_PROGRESS),
        createTime: DateTime.now().toIso8601String(),
        updateTime: DateTime.now().toIso8601String(),
        currentStep: step,
        currentAction: action,
      );
    }

    test('Default rules mark unread on state change', () async {
      mockSettingsProvider.unreadRules = [
        UnreadRule(
          id: 'rule1',
          type: RuleType.sessionState,
          action: RuleAction.markUnread,
          enabled: true,
        )
      ];

      final session1 = createSession(state: 'IN_PROGRESS');

      // Initial add (new session is unread)
      await sessionProvider.updateSession(session1, authToken: 'token');

      // Mark as read manually
      await sessionProvider.markAsRead(session1.id, 'token');

      // Ensure it is read (lastOpened >= lastUpdated)
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      // Wait a bit to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 10));

      // Update with state change
      final session2 = createSession(state: 'COMPLETED');
      await sessionProvider.updateSession(session2, authToken: 'token');

      final item = sessionProvider.items.first;
      expect(item.data.state, SessionState.COMPLETED);
      expect(item.metadata.isUnread, isTrue);
      expect(item.metadata.reasonForLastUnread, contains("State changed"));
    });

    test('Default rules mark unread on step change', () async {
      mockSettingsProvider.unreadRules = [
        UnreadRule(
          id: 'rule2',
          type: RuleType.stepChange,
          action: RuleAction.markUnread,
          enabled: true,
        )
      ];

      final session1 = createSession(step: 1);
      await sessionProvider.updateSession(session1, authToken: 'token');
      await sessionProvider.markAsRead(session1.id, 'token');
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      await Future.delayed(const Duration(milliseconds: 10));

      final session2 = createSession(step: 2);
      await sessionProvider.updateSession(session2, authToken: 'token');

      final item = sessionProvider.items.first;
      expect(item.metadata.isUnread, isTrue);
      expect(item.metadata.reasonForLastUnread, contains("Step changed"));
    });

    test('Disabling rules prevents marking unread', () async {
      mockSettingsProvider.unreadRules = [
        UnreadRule(
            id: 'rule1',
            type: RuleType.sessionState,
            action: RuleAction.markUnread,
            enabled: false)
      ];

      final session1 = createSession(state: 'IN_PROGRESS');
      await sessionProvider.updateSession(session1, authToken: 'token');
      await sessionProvider.markAsRead(session1.id, 'token');
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      await Future.delayed(const Duration(milliseconds: 10));

      final session2 = createSession(state: 'COMPLETED');
      await sessionProvider.updateSession(session2, authToken: 'token');

      final item = sessionProvider.items.first;
      expect(item.metadata.isUnread, isFalse);
    });
  });
}
