import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_jules/models/cache_metadata.dart';
import 'package:flutter_jules/services/refresh_service.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/notification_service.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/models/refresh_schedule.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/enums.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/activity_provider.dart';
import 'package:mockito/annotations.dart';
import 'refresh_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<SettingsProvider>(),
  MockSpec<SessionProvider>(),
  MockSpec<SourceProvider>(),
  MockSpec<AuthProvider>(),
  MockSpec<NotificationService>(),
  MockSpec<ActivityProvider>(),
  MockSpec<MessageQueueProvider>(),
])
void main() {
  late RefreshService refreshService;
  late MockSettingsProvider mockSettingsProvider;
  late MockSessionProvider mockSessionProvider;
  late MockSourceProvider mockSourceProvider;
  late MockAuthProvider mockAuthProvider;
  late MockNotificationService mockNotificationService;
  late MockActivityProvider mockActivityProvider;
  late MockMessageQueueProvider mockMessageQueueProvider;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockSessionProvider = MockSessionProvider();
    mockSourceProvider = MockSourceProvider();
    mockAuthProvider = MockAuthProvider();
    mockNotificationService = MockNotificationService();
    mockActivityProvider = MockActivityProvider();
    mockMessageQueueProvider = MockMessageQueueProvider();

    when(mockSettingsProvider.schedules).thenReturn([]);
    when(mockSessionProvider.items).thenReturn([]);

    refreshService = RefreshService(
      mockSettingsProvider,
      mockSessionProvider,
      mockSourceProvider,
      mockAuthProvider,
      mockNotificationService,
      mockMessageQueueProvider,
      mockActivityProvider,
    );
  });

  test('initializes timers for enabled schedules', () async {
    final schedule = RefreshSchedule(
      id: '1',
      name: 'Test Schedule',
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
        mockMessageQueueProvider,
        mockActivityProvider,
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
      name: 'Test Schedule',
      intervalInMinutes: 1,
      isEnabled: false,
      refreshPolicy: ListRefreshPolicy.quick, // Added required arg
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
        mockMessageQueueProvider,
        mockActivityProvider,
      );

      // Advance the timer by the interval
      async.elapse(const Duration(minutes: 1));

      // Should not have been called
      verifyNever(mockSessionProvider.fetchSessions(any));
    });
  });

  test('compares sessions and sends notifications', () {
    final oldSession = Session(
      id: '1',
      prompt: 'test',
      name: 'session1',
      state: SessionState.IN_PROGRESS,
    );
    final newSession = Session(
      id: '1',
      prompt: 'test',
      name: 'session1',
      state: SessionState.COMPLETED,
    );

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
    ).thenReturn(
        newSessions.map((e) => CachedItem(e, CacheMetadata.empty())).toList());

    // ignore: invalid_use_of_protected_member
    refreshService.dispose(); // Dispose the old service and its timers

    refreshService = RefreshService(
      mockSettingsProvider,
      mockSessionProvider,
      mockSourceProvider,
      mockAuthProvider,
      mockNotificationService,
      mockMessageQueueProvider,
      mockActivityProvider,
    );

    // Manually trigger the comparison
    // ignore: protected_member_use
    refreshService.compareSessions(oldSessions, newSessions);

    verify(
      mockNotificationService.showNotification(
        'Task completed',
        'Untitled Task',
        payload: 'session1',
      ),
    ).called(1);
  });
}
