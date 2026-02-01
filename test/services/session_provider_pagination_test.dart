import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/session_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';

// Create a Fake JulesClient
class FakeJulesClient extends Fake implements JulesClient {
  @override
  Future<ListSessionsResponse> listSessions({
    int? pageSize,
    String? pageToken,
    void Function(ApiExchange)? onDebug,
    bool Function(Session)? shouldStop,
  }) async {
    // Simulate delay
    await Future.delayed(const Duration(milliseconds: 10));

    if (pageToken == null) {
      // First page
      return ListSessionsResponse(
        sessions: [
          Session(
            id: '1',
            name: 'session1',
            prompt: 'prompt1',
            createTime: DateTime.now().toIso8601String(),
          ),
          Session(
            id: '2',
            name: 'session2',
            prompt: 'prompt2',
            createTime: DateTime.now().toIso8601String(),
          ),
        ],
        nextPageToken: 'page2',
      );
    } else if (pageToken == 'page2') {
      // Second page
      return ListSessionsResponse(
        sessions: [
          Session(
            id: '3',
            name: 'session3',
            prompt: 'prompt3',
            createTime: DateTime.now().toIso8601String(),
          ),
        ],
        nextPageToken: null, // End
      );
    }
    return ListSessionsResponse(sessions: [], nextPageToken: null);
  }
}

class FakeCacheService extends Fake implements CacheService {
  @override
  Future<List<CachedItem<Session>>> loadSessions(String authToken) async {
    return [];
  }

  @override
  Future<void> saveSessions(
    String authToken,
    List<CachedItem<Session>> items,
  ) async {
    return;
  }
}

void main() {
  test('SessionProvider fetches sessions incrementally', () async {
    final provider = SessionProvider();
    final client = FakeJulesClient();
    final cacheService = FakeCacheService();

    provider.setCacheService(cacheService);

    List<int> itemCounts = [];

    provider.addListener(() {
      itemCounts.add(provider.items.length);
    });

    await provider.fetchSessions(
      client,
      authToken: 'token',
      force: true,
      shallow: false,
    );

    // Verify notifications happened.
    // We expect itemCounts to contain intermediate values.
    // The exact sequence of 0s, 2s, 3s depends on how many times notifyListeners is called (e.g. for loading state changes).

    // Check that we saw 2 items at some point
    expect(itemCounts, contains(2));
    // Check that we ended up with 3 items
    expect(provider.items.length, 3);
    // Check that we saw 3 items in the history
    expect(itemCounts, contains(3));

    // Ensure incremental update happened (2 appeared before 3)
    final index2 = itemCounts.indexOf(2);
    final index3 = itemCounts.lastIndexOf(3);
    expect(index2, lessThan(index3));
  });
}
