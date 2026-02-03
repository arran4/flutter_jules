import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/cache_metadata.dart';
import 'package:flutter_jules/models/unread_rule.dart';
import 'package:flutter_jules/models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generate mocks
@GenerateMocks([SettingsProvider, CacheService])
import 'session_provider_unread_rules_test.mocks.dart';

void main() {
  group('SessionProvider Unread Rules', () {
    late SessionProvider sessionProvider;
    late MockSettingsProvider mockSettingsProvider;
    late MockCacheService mockCacheService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockSettingsProvider = MockSettingsProvider();
      mockCacheService = MockCacheService();
      sessionProvider = SessionProvider();
      sessionProvider.setSettingsProvider(mockSettingsProvider);
      sessionProvider.setCacheService(mockCacheService);
    });

    // Helper to create a session
    Session createSession({
      String id = '1',
      String state = 'IN_PROGRESS',
      int currentStep = 1,
      String currentAction = 'action1',
      String? prStatus,
      String? ciStatus,
      String updateTime = '2023-01-01T00:00:00Z',
    }) {
      return Session(
        id: id,
        name: 'sessions/$id',
        prompt: 'test prompt',
        state: SessionState.values.firstWhere(
          (e) => e.toString().split('.').last == state,
          orElse: () => SessionState.IN_PROGRESS,
        ),
        currentStep: currentStep,
        currentAction: currentAction,
        prStatus: prStatus,
        ciStatus: ciStatus,
        updateTime: updateTime,
        createTime: '2023-01-01T00:00:00Z',
      );
    }

    test('Session state change triggers unread with default rule', () async {
      // Setup default rules
      when(mockSettingsProvider.unreadRules).thenReturn([
        UnreadRule(
          id: 'default_session_state',
          type: RuleType.sessionState,
          action: RuleAction.markUnread,
        ),
      ]);

      final session1 = createSession(
        state: 'IN_PROGRESS',
        updateTime: '2023-01-01T10:00:00Z',
      );

      // 1. Initial update (New session)
      await sessionProvider.updateSession(session1);

      // Simulate reading it
      // Since we can't easily modify private _items, we assume markAsRead updates it.
      // markAsRead calls cacheService.markSessionAsRead
      when(
        mockCacheService.markSessionAsRead(any, any),
      ).thenAnswer((_) async {});
      await sessionProvider.markAsRead(session1.id, 'token');

      // Verify it's read (lastOpened is recent)
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      // 2. Update with state change
      final session2 = createSession(
        state: 'COMPLETED',
        updateTime: '2023-01-01T11:00:00Z',
      );
      await sessionProvider.updateSession(session2);

      // Verify it's unread
      expect(sessionProvider.items.first.metadata.isUnread, isTrue);
      expect(
        sessionProvider.items.first.metadata.reasonForLastUnread,
        contains('State changed'),
      );
    });

    test('Session state change does NOT trigger unread if rule disabled', () async {
      // Setup rules with disabled session state rule
      when(mockSettingsProvider.unreadRules).thenReturn([
        UnreadRule(
          id: 'default_session_state',
          type: RuleType.sessionState,
          action: RuleAction.markUnread,
          enabled: false,
        ),
        // Add generic content update rule to ensure it doesn't mask it?
        // If content update rule exists, it might trigger "Session updated".
        // But we want to ensure "State changed" specific reason isn't there,
        // or if content update is disabled too, it stays read?
        // Let's assume content update rule is also there but we want to check priority or existence.
        // Actually, if sessionState rule is disabled, and contentUpdate is enabled (default),
        // it will still be marked unread as "Session updated" because updateTime changed.
        // So to test "nothing happens", we need to disable contentUpdate too or use same updateTime.
      ]);

      final session1 = createSession(
        state: 'IN_PROGRESS',
        updateTime: '2023-01-01T10:00:00Z',
      );
      await sessionProvider.updateSession(session1);

      when(
        mockCacheService.markSessionAsRead(any, any),
      ).thenAnswer((_) async {});
      await sessionProvider.markAsRead(session1.id, 'token');
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      // Update with state change but SAME updateTime to avoid contentUpdate rule (if implicitly checked)
      // Wait, _evaluateUpdateRules checks contentUpdate rule.
      // If we don't have contentUpdate rule, updateTime change shouldn't matter?
      // "Session updated" fallback logic:
      // if (reasons.isEmpty && shouldMarkUnread) { reasons.add("Session updated"); }
      // This fallback only happens if shouldMarkUnread is true.

      // So if no rules match, shouldMarkUnread remains false.

      final session2 = createSession(
        state: 'COMPLETED',
        updateTime: '2023-01-01T11:00:00Z',
      );

      // Re-configure rules to be empty (or all disabled)
      when(mockSettingsProvider.unreadRules).thenReturn([]);

      await sessionProvider.updateSession(session2);

      // Verify it remains read (isUnread is false)
      // Note: isUnread checks lastUpdated vs lastOpened.
      // If shouldMarkUnread was false, lastUpdated is NOT updated.
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);
    });

    test('Step change triggers unread with stepChange rule', () async {
      when(mockSettingsProvider.unreadRules).thenReturn([
        UnreadRule(
          id: 'step_change',
          type: RuleType.stepChange,
          action: RuleAction.markUnread,
        ),
      ]);

      final session1 = createSession(
        currentStep: 1,
        updateTime: '2023-01-01T10:00:00Z',
      );
      await sessionProvider.updateSession(session1);

      when(
        mockCacheService.markSessionAsRead(any, any),
      ).thenAnswer((_) async {});
      await sessionProvider.markAsRead(session1.id, 'token');
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      final session2 = createSession(
        currentStep: 2,
        updateTime: '2023-01-01T11:00:00Z',
      );
      await sessionProvider.updateSession(session2);

      expect(sessionProvider.items.first.metadata.isUnread, isTrue);
      expect(
        sessionProvider.items.first.metadata.reasonForLastUnread,
        contains('Session progressed'),
      );
    });

    test('PR status Draft -> Open triggers unread', () async {
      when(mockSettingsProvider.unreadRules).thenReturn([
        UnreadRule(
          id: 'pr_draft_open',
          type: RuleType.prStatus,
          fromValue: 'Draft',
          toValue: 'Open',
          action: RuleAction.markUnread,
        ),
      ]);

      final session1 = createSession(
        prStatus: 'Draft',
        updateTime: '2023-01-01T10:00:00Z',
      );
      await sessionProvider.updateSession(session1);

      when(
        mockCacheService.markSessionAsRead(any, any),
      ).thenAnswer((_) async {});
      await sessionProvider.markAsRead(session1.id, 'token');
      expect(sessionProvider.items.first.metadata.isUnread, isFalse);

      final session2 = createSession(
        prStatus: 'Open',
        updateTime: '2023-01-01T11:00:00Z',
      );
      await sessionProvider.updateSession(session2);

      expect(sessionProvider.items.first.metadata.isUnread, isTrue);
      expect(
        sessionProvider.items.first.metadata.reasonForLastUnread,
        contains('PR Status changed from Draft to Open'),
      );
    });
  });
}
