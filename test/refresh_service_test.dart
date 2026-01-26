import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_jules/services/refresh_service.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/notification_service.dart';
import 'package:flutter_jules/models/refresh_schedule.dart';
import 'package:flutter_jules/models/enums.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/activity_provider.dart';
import 'package:flutter_jules/services/timer_service.dart';
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
class MockJulesClient extends Mock implements JulesClient {}

void main() {
  late RefreshService refreshService;
  late MockSettingsProvider mockSettingsProvider;
  late MockSessionProvider mockSessionProvider;
  late MockSourceProvider mockSourceProvider;
  late MockAuthProvider mockAuthProvider;
  late MockNotificationService mockNotificationService;
  late MockActivityProvider mockActivityProvider;
  late MockMessageQueueProvider mockMessageQueueProvider;
  late TimerService timerService;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockSessionProvider = MockSessionProvider();
    mockSourceProvider = MockSourceProvider();
    mockAuthProvider = MockAuthProvider();
    mockNotificationService = MockNotificationService();
    mockActivityProvider = MockActivityProvider();
    mockMessageQueueProvider = MockMessageQueueProvider();
    timerService = TimerService();

    when(mockAuthProvider.client).thenReturn(MockJulesClient());
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
      timerService,
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
      timerService.dispose();
      timerService = TimerService();
      refreshService = RefreshService(
        mockSettingsProvider,
        mockSessionProvider,
        mockSourceProvider,
        mockAuthProvider,
        mockNotificationService,
        mockMessageQueueProvider,
        mockActivityProvider,
        timerService,
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
      timerService.dispose();
      timerService = TimerService();
      refreshService = RefreshService(
        mockSettingsProvider,
        mockSessionProvider,
        mockSourceProvider,
        mockAuthProvider,
        mockNotificationService,
        mockMessageQueueProvider,
        mockActivityProvider,
        timerService,
      );

      // Advance the timer by the interval
      async.elapse(const Duration(minutes: 1));

      // Should not have been called
      verifyNever(mockSessionProvider.fetchSessions(any));
    });
  });

  test('getNextScheduledRefresh returns the next scheduled run', () {
    final schedule1 = RefreshSchedule(
      id: '1',
      name: 'Schedule 1',
      intervalInMinutes: 10,
      isEnabled: true,
      lastRun: DateTime.now().subtract(const Duration(minutes: 5)),
      refreshPolicy: ListRefreshPolicy.quick,
    );
    final schedule2 = RefreshSchedule(
      id: '2',
      name: 'Schedule 2',
      intervalInMinutes: 20,
      isEnabled: true,
      lastRun: DateTime.now().subtract(const Duration(minutes: 5)),
      refreshPolicy: ListRefreshPolicy.full,
    );
    when(mockSettingsProvider.schedules).thenReturn([schedule1, schedule2]);

    final result = refreshService.getNextScheduledRefresh();
    expect(result, isNotNull);
    expect(result!.schedule.id, equals('1'));
    // Schedule 1 is 10 mins interval, last run 5 mins ago. Next run is in 5 mins.
    // Schedule 2 is 20 mins interval, last run 5 mins ago. Next run is in 15 mins.
    // So Schedule 1 should be next.
  });

  test('getNextScheduledRefresh handles no schedules', () {
    when(mockSettingsProvider.schedules).thenReturn([]);
    final result = refreshService.getNextScheduledRefresh();
    expect(result, isNull);
  });
}
