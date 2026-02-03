import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';

// Manual mocks
class MockSettingsProvider extends SettingsProvider {
  List<UnreadRule> _mockRules = [];

  @override
  List<UnreadRule> get unreadRules => _mockRules;

  void setRules(List<UnreadRule> rules) {
    _mockRules = rules;
  }
}

class MockCacheService extends CacheService {
  @override
  Future<void> saveSessions(String token, List<CachedItem<Session>> sessions) async {}

  @override
  Future<void> markSessionAsRead(String token, String sessionId) async {}
}

void main() {
  group('SessionProvider Unread Rules', () {
    late SessionProvider sessionProvider;
    late MockSettingsProvider settingsProvider;
    late MockCacheService cacheService;

    setUp(() {
      sessionProvider = SessionProvider();
      settingsProvider = MockSettingsProvider();
      cacheService = MockCacheService();

      sessionProvider.setSettingsProvider(settingsProvider);
      sessionProvider.setCacheService(cacheService);
    });

    test('Session State Rule applies correctly', () async {
      settingsProvider.setRules([
        UnreadRule(
          id: '1',
          type: RuleType.sessionState,
          action: RuleAction.markUnread,
        ),
      ]);

      final session1 = Session(
        id: 's1',
        name: 'sessions/s1',
        prompt: 'test',
        state: SessionState.IN_PROGRESS,
        createTime: DateTime.now().toIso8601String(),
        updateTime: DateTime.now().toIso8601String(),
      );

      // Add initial session
      await sessionProvider.updateSession(session1);

      // Mark as read manually to clear "New Session" status
      await sessionProvider.markAsRead('s1', 'token');

      // Verify it is read (lastOpened > lastUpdated or lastUpdated is old)
      // markAsRead sets lastOpened to now.

      // Update session with new state
      final session2 = session1.copyWith(state: SessionState.COMPLETED);

      // Wait a bit to ensure time difference if using DateTime.now()
      await Future.delayed(const Duration(milliseconds: 10));

      await sessionProvider.updateSession(session2);

      final item = sessionProvider.items.first;
      // Should be unread now
      expect(item.metadata.lastUpdated, isNotNull);
      if (item.metadata.lastOpened != null) {
         expect(item.metadata.lastUpdated!.isAfter(item.metadata.lastOpened!), isTrue, reason: "Last updated should be after last opened");
      }
      expect(item.metadata.reasonForLastUnread, contains("State changed"));
    });

    test('Step Change Rule applies correctly', () async {
      settingsProvider.setRules([
        UnreadRule(
          id: '1',
          type: RuleType.stepChange,
          action: RuleAction.markUnread,
        ),
      ]);

      final session1 = Session(
        id: 's1',
        name: 'sessions/s1',
        prompt: 'test',
        currentStep: 1,
        createTime: DateTime.now().toIso8601String(),
        updateTime: DateTime.now().toIso8601String(),
      );

      await sessionProvider.updateSession(session1);
      await sessionProvider.markAsRead('s1', 'token');
      await Future.delayed(const Duration(milliseconds: 10));

      final session2 = session1.copyWith(currentStep: 2);
      await sessionProvider.updateSession(session2);

      final item = sessionProvider.items.first;
      expect(item.metadata.lastUpdated!.isAfter(item.metadata.lastOpened!), isTrue);
      expect(item.metadata.reasonForLastUnread, contains("Session progressed"));
    });

    test('Disabling rules works', () async {
      settingsProvider.setRules([
        UnreadRule(
          id: '1',
          type: RuleType.sessionState,
          action: RuleAction.markUnread,
          enabled: false,
        ),
      ]);

      final session1 = Session(
        id: 's1',
        name: 'sessions/s1',
        prompt: 'test',
        state: SessionState.IN_PROGRESS,
        createTime: DateTime.now().toIso8601String(),
        updateTime: DateTime.now().toIso8601String(),
      );

      await sessionProvider.updateSession(session1);
      await sessionProvider.markAsRead('s1', 'token');
      await Future.delayed(const Duration(milliseconds: 10));

      final session2 = session1.copyWith(state: SessionState.COMPLETED);
      await sessionProvider.updateSession(session2);

      final item = sessionProvider.items.first;
      // Should remain read because rule is disabled
      // lastUpdated shouldn't have been updated (or at least shouldn't trigger unread if we logic it right,
      // but updateSession updates lastUpdated only if shouldMarkUnread is true)

      // If shouldMarkUnread is false, lastUpdated is kept from oldItem.metadata.lastUpdated

      // oldItem.metadata.lastUpdated was set at creation.
      // markAsRead set lastOpened > lastUpdated.
      // So if lastUpdated is not changed, it is still < lastOpened.

      expect(item.metadata.lastUpdated!.isBefore(item.metadata.lastOpened!), isTrue);
    });
  });
}
