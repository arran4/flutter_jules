import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/models/enums.dart';

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
          provider.appBarRefreshActions, contains(RefreshButtonAction.refresh));
      expect(provider.appBarRefreshActions.length, 1);
    });

    test('Can update and persist refresh actions', () async {
      final newActions = {
        RefreshButtonAction.fullRefresh,
        RefreshButtonAction.refreshDirty
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

    test('Can update and persist unread trigger settings', () async {
      // Defaults are false
      expect(provider.markUnreadOnPrStatusChange, isFalse);
      expect(provider.markUnreadOnCiStatusChange, isFalse);
      expect(provider.markUnreadOnComment, isFalse);

      await provider.setMarkUnreadOnPrStatusChange(true);
      await provider.setMarkUnreadOnCiStatusChange(true);
      await provider.setMarkUnreadOnComment(true);

      expect(provider.markUnreadOnPrStatusChange, isTrue);
      expect(provider.markUnreadOnCiStatusChange, isTrue);
      expect(provider.markUnreadOnComment, isTrue);

      final provider2 = SettingsProvider();
      await provider2.init();
      expect(provider2.markUnreadOnPrStatusChange, isTrue);
      expect(provider2.markUnreadOnCiStatusChange, isTrue);
      expect(provider2.markUnreadOnComment, isTrue);
    });
  });
}
