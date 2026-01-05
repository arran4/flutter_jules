import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:jules_client/services/source_provider.dart';
import 'package:jules_client/services/jules_client.dart';
import 'package:jules_client/models/source.dart';
import 'package:jules_client/models/cache_metadata.dart';
import 'package:jules_client/services/cache_service.dart';

// Mock JulesClient
class MockJulesClient extends Mock implements JulesClient {}

// Mock CacheService
class MockCacheService extends Mock implements CacheService {}

void main() {
  group('SourceProvider', () {
    late SourceProvider provider;
    late MockJulesClient mockClient;
    late MockCacheService mockCacheService;

    setUp(() {
      provider = SourceProvider();
      mockClient = MockJulesClient();
      mockCacheService = MockCacheService();
      provider.setCacheService(mockCacheService);
    });

    tearDown(() {
      reset(mockClient);
      reset(mockCacheService);
    });

    final source1 = Source(name: 'source1', id: 'id1');
    final source2 = Source(name: 'source2', id: 'id2');
    const authToken = 'test_token';
    final metadata =
        CacheMetadata(firstSeen: DateTime.now(), lastRetrieved: DateTime.now());

    test('fetchSources loads and caches data when cache is empty', () async {
      // Arrange
      final sources = [source1, source2];
      final cachedItems = sources.map((s) => CachedItem(s, metadata)).toList();
      var loadSourcesCallCount = 0;

      when(mockCacheService.loadSources(authToken)).thenAnswer((_) async {
        loadSourcesCallCount++;
        if (loadSourcesCallCount == 1) {
          return <CachedItem<Source>>[]; // First call, empty cache
        }
        return cachedItems; // Subsequent calls, after saving
      });

      when(mockClient.listSources(pageToken: null)).thenAnswer((_) async =>
          ListSourcesResponse(sources: [source1], nextPageToken: 'next'));
      when(mockClient.listSources(pageToken: 'next')).thenAnswer((_) async =>
          ListSourcesResponse(sources: [source2], nextPageToken: null));

      // Act
      await provider.fetchSources(mockClient, authToken: authToken);

      // Assert
      expect(provider.items.map((e) => e.data), sources);
      verify(mockCacheService.saveSources(authToken, sources)).called(1);
      verify(mockClient.listSources(pageToken: null)).called(1);
      verify(mockClient.listSources(pageToken: 'next')).called(1);
      verify(mockCacheService.loadSources(authToken)).called(2);
    });

    test('fetchSources uses cache and does not fetch if not forced', () async {
      // Arrange
      final cachedItems = [CachedItem(source1, metadata)];
      when(mockCacheService.loadSources(authToken))
          .thenAnswer((_) async => cachedItems);

      // Act
      await provider.fetchSources(mockClient,
          authToken: authToken, force: false);

      // Assert
      expect(provider.items.map((e) => e.data), [source1]);
      verifyNever(mockClient.listSources(pageToken: anyNamed('pageToken')));
      verify(mockCacheService.loadSources(authToken)).called(1);
    });

    test('fetchSources fetches data if forced, even with cache', () async {
      // Arrange
      final oldCachedItems = [CachedItem(source1, metadata)];
      final newSource = Source(name: 'new_source', id: 'id_new');
      final newCachedItems = [CachedItem(newSource, metadata)];
      var loadSourcesCallCount = 0;

      when(mockCacheService.loadSources(authToken)).thenAnswer((_) async {
        loadSourcesCallCount++;
        if (loadSourcesCallCount == 1) {
          return oldCachedItems; // Initial load from cache
        }
        return newCachedItems; // Load after save
      });
      when(mockClient.listSources(pageToken: anyNamed('pageToken'))).thenAnswer(
          (_) async =>
              ListSourcesResponse(sources: [newSource], nextPageToken: null));
      when(mockCacheService.saveSources(authToken, [newSource]))
          .thenAnswer((_) async {});

      // Act
      await provider.fetchSources(mockClient,
          authToken: authToken, force: true);

      // Assert
      expect(provider.items.map((e) => e.data), [newSource]);
      verify(mockClient.listSources(pageToken: null)).called(1);
      verify(mockCacheService.saveSources(authToken, [newSource])).called(1);
      verify(mockCacheService.loadSources(authToken)).called(2);
    });

    test('fetchSources handles API errors gracefully', () async {
      // Arrange
      when(mockCacheService.loadSources(authToken)).thenAnswer((_) async => []);
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenThrow(Exception('Network error'));

      // Act
      await provider.fetchSources(mockClient, authToken: authToken);

      // Assert
      expect(provider.items, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, contains('Exception: Network error'));
      verify(mockCacheService.loadSources(authToken)).called(1);
    });

    test('ensureSourceAvailable fetches if source is missing', () async {
      // Arrange
      final newCachedItems = [CachedItem(source1, metadata)];
      var loadSourcesCallCount = 0;

      when(mockCacheService.loadSources(authToken)).thenAnswer((_) async {
        loadSourcesCallCount++;
        if (loadSourcesCallCount == 1) {
          return []; // empty on first check inside ensureSourceAvailable->fetchSources
        }
        return newCachedItems; // loaded after save
      });
      when(mockClient.listSources(pageToken: anyNamed('pageToken'))).thenAnswer(
          (_) async =>
              ListSourcesResponse(sources: [source1], nextPageToken: null));
      when(mockCacheService.saveSources(authToken, [source1]))
          .thenAnswer((_) async {});

      // Act
      await provider.ensureSourceAvailable(mockClient, 'source1',
          authToken: authToken);

      // Assert
      expect(provider.items.map((e) => e.data), [source1]);
      verify(mockClient.listSources(pageToken: null)).called(1);
    });

    test('ensureSourceAvailable does not fetch if source is present', () async {
      // Arrange
      final cachedItems = [CachedItem(source1, metadata)];
      when(mockCacheService.loadSources(authToken))
          .thenAnswer((_) async => cachedItems);
      // Pre-populate the provider
      await provider.fetchSources(mockClient, authToken: authToken);
      clearInteractions(mockClient);
      clearInteractions(mockCacheService);

      // Act
      await provider.ensureSourceAvailable(mockClient, 'source1',
          authToken: authToken);

      // Assert
      verifyZeroInteractions(mockClient);
    });
  });
}
