import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/refresh_service.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/notification_service.dart';
import 'package:flutter_jules/models/refresh_schedule.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/enums.dart';

class MockSettingsProvider extends Mock implements SettingsProvider {}

class MockSessionProvider extends Mock implements SessionProvider {}

class MockSourceProvider extends Mock implements SourceProvider {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late RefreshService refreshService;
  late MockSettingsProvider mockSettingsProvider;
  late MockSessionProvider mockSessionProvider;
  late MockSourceProvider mockSourceProvider;
  late MockAuthProvider mockAuthProvider;
  late MockNotificationService mockNotificationService;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockSessionProvider = MockSessionProvider();
    mockSourceProvider = MockSourceProvider();
    mockAuthProvider = MockAuthProvider();
    mockNotificationService = MockNotificationService();

    when(mockSettingsProvider.schedules).thenReturn([]);
    when(mockSessionProvider.items).thenReturn([]);

    refreshService = RefreshService(
      mockSettingsProvider,
      mockSessionProvider,
      mockSourceProvider,
      mockAuthProvider,
      mockNotificationService,
    );
  });

  test('initializes timers for enabled schedules', () async {
    final schedule = RefreshSchedule(
      id: '1',
      intervalInMinutes: 1,
      isEnabled: true,
      refreshPolicy: ListRefreshPolicy.quick,
    );
    when(mockSettingsProvider.schedules).thenReturn([schedule]);

    fakeAsync((async) {
      refreshService.dispose(); // Dispose the old service
      refreshService = RefreshService(
        mockSettingsProvider,
        mockSessionProvider,
        mockSourceProvider,
        mockAuthProvider,
        mockNotificationService,
      );

      // Should not have been called yet
      verifyNever(mockSessionProvider.fetchSessions(any));

      // Advance the timer by the interval
      async.elapse(const Duration(minutes: 1));

      // Should have been called now
      verify(mockSessionProvider.fetchSessions(any)).called(1);
    });
  });

  test('does not initialize timers for disabled schedules', () async {
    final schedule = RefreshSchedule(
      id: '1',
      intervalInMinutes: 1,
      isEnabled: false,
    );
    when(mockSettingsProvider.schedules).thenReturn([schedule]);

    fakeAsync((async) {
      refreshService.dispose(); // Dispose the old service
      refreshService = RefreshService(
        mockSettingsProvider,
        mockSessionProvider,
        mockSourceProvider,
        mockAuthProvider,
        mockNotificationService,
      );

      // Advance the timer by the interval
      async.elapse(const Duration(minutes: 1));

      // Should not have been called
      verifyNever(mockSessionProvider.fetchSessions(any));
    });
  });

  test('compares sessions and sends notifications', () {
    final oldSession = Session(
      name: 'session1',
      state: SessionState.IN_PROGRESS,
    );
    final newSession = Session(name: 'session1', state: SessionState.COMPLETED);

    when(mockSettingsProvider.notifyOnCompletion).thenReturn(true);
    when(mockSettingsProvider.notifyOnAttention).thenReturn(false);
    when(mockSettingsProvider.notifyOnFailure).thenReturn(false);
    when(mockSettingsProvider.notifyOnWatch).thenReturn(false);

    // This is a bit of a hack to test a private method
    // In a real app, you might want to refactor this to be more testable
    final oldSessions = [oldSession];
    final newSessions = [newSession];

    when(
      mockSessionProvider.items,
    ).thenReturn(newSessions.map((e) => CachedItem(e)).toList());

    // ignore: invalid_use_of_protected_member
    refreshService.dispose(); // Dispose the old service and its timers

    refreshService = RefreshService(
      mockSettingsProvider,
      mockSessionProvider,
      mockSourceProvider,
      mockAuthProvider,
      mockNotificationService,
    );

    // Manually trigger the comparison
    // ignore: protected_member_use
    (refreshService as dynamic)._compareSessions(oldSessions, newSessions);

    verify(
      mockNotificationService.showNotification(
        'Task completed',
        'Untitled Task',
        payload: 'session1',
      ),
    ).called(1);
  });
}
