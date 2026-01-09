import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_jules/services/message_queue_provider.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/cache_service.dart';
import 'package:flutter_jules/models/api_exchange.dart';
import 'package:flutter_jules/models/queued_message.dart';
import 'package:flutter_jules/models/session.dart'; // Needed for listSessions return type

// Mock JulesClient
class MockJulesClient extends Mock implements JulesClient {
  @override
  Future<void> sendMessage(String? sessionName, String? message,
      {void Function(ApiExchange)? onDebug}) {
    return super.noSuchMethod(
      Invocation.method(
          #sendMessage, [sessionName, message], {#onDebug: onDebug}),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }

  @override
  Future<ListSessionsResponse> listSessions(
      {int? pageSize,
      String? pageToken,
      void Function(ApiExchange)? onDebug,
      bool Function(Session)? shouldStop}) {
    return super.noSuchMethod(
      Invocation.method(#listSessions, [], {
        #pageSize: pageSize,
        #pageToken: pageToken,
        #onDebug: onDebug,
        #shouldStop: shouldStop
      }),
      returnValue: Future.value(ListSessionsResponse(sessions: [])),
      returnValueForMissingStub:
          Future.value(ListSessionsResponse(sessions: [])),
    );
  }
}

// Mock CacheService
class MockCacheService extends Mock implements CacheService {
  @override
  Future<void> saveMessageQueue(String? token, List<QueuedMessage>? queue) {
    return super.noSuchMethod(
      Invocation.method(#saveMessageQueue, [token, queue]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }

  @override
  Future<List<QueuedMessage>> loadMessageQueue(String? token) {
    return super.noSuchMethod(
      Invocation.method(#loadMessageQueue, [token]),
      returnValue: Future.value(<QueuedMessage>[]),
      returnValueForMissingStub: Future.value(<QueuedMessage>[]),
    );
  }
}

void main() {
  group('MessageQueueProvider', () {
    late MessageQueueProvider provider;
    late MockJulesClient mockClient;
    late MockCacheService mockCacheService;

    setUp(() {
      provider = MessageQueueProvider();
      mockClient = MockJulesClient();
      mockCacheService = MockCacheService();
      provider.setCacheService(mockCacheService, 'test-token');
    });

    test('addMessage adds to queue and saves', () {
      provider.addMessage('session-1', 'Hello World');

      expect(provider.queue.length, 1);
      expect(provider.queue.first.content, 'Hello World');
      expect(provider.queue.first.sessionId, 'session-1');

      verify(mockCacheService.saveMessageQueue(any, any)).called(1);
    });

    test('deleteMessage removes from queue and saves', () {
      provider.addMessage('session-1', 'Msg 1');
      final id = provider.queue.first.id;

      provider.deleteMessage(id);

      expect(provider.queue, isEmpty);
      verify(mockCacheService.saveMessageQueue(any, any))
          .called(2); // 1 add, 1 delete
    });

    test('updateMessage updates content and saves', () {
      provider.addMessage('session-1', 'Msg 1');
      final id = provider.queue.first.id;

      provider.updateMessage(id, 'Updated Msg');

      expect(provider.queue.first.content, 'Updated Msg');
      verify(mockCacheService.saveMessageQueue(any, any)).called(2);
    });

    test('goOnline checks connection', () async {
      when(mockClient.listSessions(pageSize: 1))
          .thenAnswer((_) async => ListSessionsResponse(sessions: []));

      provider.setOffline(true);
      expect(provider.isOffline, true);

      final result = await provider.goOnline(mockClient);

      expect(result, true);
      expect(provider.isOffline, false);
    });

    test('goOnline fails stays offline', () async {
      when(mockClient.listSessions(pageSize: 1))
          .thenThrow(Exception('Network Error'));

      provider.setOffline(true);
      expect(provider.isOffline, true);

      final result = await provider.goOnline(mockClient);

      expect(result, false);
      expect(provider.isOffline, true);
    });

    test('sendQueue sends messages and removes them', () async {
      provider.addMessage('session-1', 'Msg 1');
      provider.addMessage('session-2', 'Msg 2');

      when(mockClient.sendMessage(any, any)).thenAnswer((_) => Future.value());

      await provider.sendQueue(mockClient);

      verify(mockClient.sendMessage('session-1', 'Msg 1')).called(1);
      verify(mockClient.sendMessage('session-2', 'Msg 2')).called(1);
      expect(provider.queue, isEmpty);
      verify(mockCacheService.saveMessageQueue(any, any))
          .called(greaterThan(0));
    });

    test('sendQueue stops on error', () async {
      provider.addMessage('s1', 'Good');
      provider.addMessage('s2', 'Bad');
      provider.addMessage('s3', 'Pending');

      // Ensure specific order by mocking 'addMessage' timestamps if needed,
      // but here they are added in order so likely sorted by default (list order).
      // Actually provider sorts by createdAt. sequential adds should be fine.

      when(mockClient.sendMessage('s1', 'Good'))
          .thenAnswer((_) => Future.value());
      when(mockClient.sendMessage('s2', 'Bad')).thenThrow(Exception('Fail'));

      bool errorCalled = false;
      await provider.sendQueue(mockClient, onError: (id, e) {
        errorCalled = true;
      });

      verify(mockClient.sendMessage('s1', 'Good')).called(1);
      verify(mockClient.sendMessage('s2', 'Bad')).called(1);
      verifyNever(mockClient.sendMessage('s3', any));

      expect(errorCalled, true);
      expect(provider.queue.length, 2); // s2 and s3 remain
      expect(provider.queue[0].content, 'Bad');
    });
  });
}
