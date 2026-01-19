import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_jules/services/refresh_service.dart';
import 'package:flutter_jules/services/settings_provider.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/auth_provider.dart';
import 'package:flutter_jules/services/notification_service.dart';
import 'package:flutter_jules/models/refresh_schedule.dart';
import 'package:flutter_jules/models/enums.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/activity_provider.dart';
import 'package:flutter_jules/services/exceptions.dart';
import 'package:flutter_jules/services/jules_client.dart';

import 'refresh_service_test.mocks.dart';

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
    // Ensure notifyOnErrors is true so we can verify the notification
    when(mockSettingsProvider.notifyOnErrors).thenReturn(true);
    when(mockAuthProvider.token).thenReturn('test_token');

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

  test('reports InvalidTokenException correctly', () {
    final schedule = RefreshSchedule(
      id: '1',
      name: 'Test Schedule',
      intervalInMinutes: 1,
      isEnabled: true,
      refreshPolicy: ListRefreshPolicy.quick,
    );
    when(mockSettingsProvider.schedules).thenReturn([schedule]);

    // Simulate InvalidTokenException being thrown by SessionProvider
    // Note: This assumes we will modify SessionProvider to rethrow this exception.
    // If SessionProvider currently swallows it, this test setup mimics the behavior
    // AFTER we modify SessionProvider, or simulates the exception propagating somehow.
    // However, since we are mocking SessionProvider, we control what it does.
    // To test RefreshService's handling, we just make the mock throw.
    when(mockSessionProvider.fetchSessions(any)).thenAnswer((_) async {
      throw InvalidTokenException('{"error": "unauthenticated"}');
    });

    fakeAsync((async) {
      refreshService.dispose();
      refreshService = RefreshService(
        mockSettingsProvider,
        mockSessionProvider,
        mockSourceProvider,
        mockAuthProvider,
        mockNotificationService,
        mockMessageQueueProvider,
        mockActivityProvider,
      );

      // Advance timer
      async.elapse(const Duration(minutes: 1));

      // Verify that notification service was called with specific error message
      verify(mockNotificationService.showNotification(
        'Authentication Error',
        'Invalid API token provided. Please check your settings.',
        payload: 'auth_error'
      )).called(1);
    });
  });
}
