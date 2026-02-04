import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models.dart';
import 'package:flutter_jules/services/jules_client.dart';
import 'package:flutter_jules/services/source_provider.dart';
import 'package:flutter_jules/services/cache_service.dart';

// Create a Fake JulesClient
class FakeJulesClient extends Fake implements JulesClient {
  @override
  Future<ListSourcesResponse> listSources({
    int? pageSize,
    String? pageToken,
    void Function(ApiExchange)? onDebug,
  }) async {
    // Simulate delay
    await Future.delayed(const Duration(milliseconds: 10));

    if (pageToken == null) {
      // First page
      return ListSourcesResponse(
        sources: [
          Source(name: 'source1', id: '1'),
          Source(name: 'source2', id: '2'),
        ],
        nextPageToken: 'page2',
      );
    } else if (pageToken == 'page2') {
      // Second page
      return ListSourcesResponse(
        sources: [Source(name: 'source3', id: '3')],
        nextPageToken: null, // End
      );
    }
    return ListSourcesResponse(sources: [], nextPageToken: null);
  }
}

class FakeCacheService extends Fake implements CacheService {
  @override
  Future<List<CachedItem<Source>>> loadSources(String authToken) async {
    return [];
  }

  @override
  Future<void> saveSources(String authToken, List<Source> items) async {
    return;
  }
}

void main() {
  test('SourceProvider updates loadingStatus during fetch', () async {
    final provider = SourceProvider();
    final client = FakeJulesClient();
    final cacheService = FakeCacheService();

    // provider.setCacheService(cacheService);

    List<String> statuses = [];
    List<bool> loadingStates = [];

    provider.addListener(() {
      loadingStates.add(provider.isLoading);
      statuses.add(provider.loadingStatus);
    });

    await provider.fetchSources(client, authToken: 'token', force: true);

    expect(provider.items.length, 3);

    // Check loading status updates
    expect(statuses, contains('Refreshing...'));
    expect(statuses, contains('Loaded 2 sources...'));
    expect(statuses, contains('Loaded 3 sources...'));
  });
}
