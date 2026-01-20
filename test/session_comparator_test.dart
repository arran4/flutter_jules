import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/session_comparator.dart';
import 'package:flutter_jules/models/session.dart';
import 'package:flutter_jules/models/enums.dart';

import 'refresh_service_test.mocks.dart';

void main() {
  late SessionComparator sessionComparator;
  late MockSettingsProvider mockSettingsProvider;
  late MockNotificationService mockNotificationService;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockNotificationService = MockNotificationService();
    sessionComparator = SessionComparator(mockSettingsProvider, mockNotificationService);
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

    final oldSessions = [oldSession];
    final newSessions = [newSession];

    sessionComparator.compare(oldSessions, newSessions);

    verify(
      mockNotificationService.showNotification(
        'Task completed',
        'Untitled Task',
        payload: 'session1',
      ),
    ).called(1);
  });
}
