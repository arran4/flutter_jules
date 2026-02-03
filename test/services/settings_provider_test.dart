import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/models/enums.dart';
import 'package:flutter_jules/models/unread_rule.dart';

void main() {
  group('SettingsProvider', () {
    late SettingsProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = SettingsProvider();
      await provider.init();
    });

    test('Refresh actions default to simple refresh', () {
      expect(
        provider.appBarRefreshActions,
        contains(RefreshButtonAction.refresh),
      );
      expect(provider.appBarRefreshActions.length, 1);
    });

    test('Can update and persist refresh actions', () async {
      final newActions = {
        RefreshButtonAction.fullRefresh,
        RefreshButtonAction.refreshDirty,
      };
      await provider.setAppBarRefreshActions(newActions);

      expect(provider.appBarRefreshActions, equals(newActions));

      // Verify persistence (re-init)
      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.appBarRefreshActions, equals(newActions));
    });

    test('Can set empty refresh actions', () async {
      await provider.setAppBarRefreshActions({});
      expect(provider.appBarRefreshActions, isEmpty);

      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.appBarRefreshActions, isEmpty);
    });

    test('Can update and persist unread rules', () async {
      // Default is not empty anymore
      expect(provider.unreadRules, isNotEmpty);

      final rule = UnreadRule(
        id: 'test-rule',
        type: RuleType.prStatus,
        action: RuleAction.markUnread,
        fromValue: 'Open',
        toValue: 'Merged',
      );

      await provider.addUnreadRule(rule);
      expect(provider.unreadRules.length, 7);
      expect(provider.unreadRules.last.id, 'test-rule');

      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.unreadRules.length, 7);
      expect(provider2.unreadRules.last.id, 'test-rule');
      expect(provider2.unreadRules.last.type, RuleType.prStatus);
    });

    test('Can restore default unread rules', () async {
      await provider.setAppBarRefreshActions({}); // Just to change something

      // Add a custom rule
      final rule = UnreadRule(
        id: 'custom-rule',
        type: RuleType.contentUpdate,
        action: RuleAction.markRead,
      );
      await provider.addUnreadRule(rule);
      expect(provider.unreadRules.length, 7); // 6 defaults + 1 custom

      // Delete all rules
      for (var r in List.of(provider.unreadRules)) {
        await provider.deleteUnreadRule(r.id);
      }
      expect(provider.unreadRules, isEmpty);

      // Restore defaults
      await provider.restoreDefaultUnreadRules();
      expect(provider.unreadRules.length, 6);
      expect(
        provider.unreadRules.any((r) => r.id == 'default_session_state'),
        isTrue,
      );
    });
  });
}
