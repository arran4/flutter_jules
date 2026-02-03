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

    test('Unread rules are populated with defaults on first load', () {
      expect(provider.unreadRules, isNotEmpty);
      expect(provider.unreadRules.length, 5); // 5 default rules
      expect(provider.unreadRules.any((r) => r.type == RuleType.sessionState),
          isTrue);
      expect(provider.unreadRules.any((r) => r.type == RuleType.stepChange),
          isTrue);
    });

    test('Can update and persist unread rules', () async {
      // Should have defaults
      expect(provider.unreadRules, isNotEmpty);

      final rule = UnreadRule(
        id: 'test-rule',
        type: RuleType.prStatus,
        action: RuleAction.markUnread,
        fromValue: 'Open',
        toValue: 'Merged',
      );

      await provider.addUnreadRule(rule);
      expect(provider.unreadRules.any((r) => r.id == 'test-rule'), isTrue);

      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.unreadRules.any((r) => r.id == 'test-rule'), isTrue);
    });
  });
}
