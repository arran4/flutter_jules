import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:jules_client/services/source_provider.dart';
import 'package:jules_client/services/jules_client.dart';
import 'package:jules_client/models/source.dart';
import 'package:jules_client/models/api_exchange.dart';

// Mock JulesClient
class MockJulesClient extends Mock implements JulesClient {
  @override
  Future<ListSourcesResponse> listSources({int? pageSize, String? pageToken, void Function(ApiExchange)? onDebug}) {
    return super.noSuchMethod(
      Invocation.method(#listSources, [], {#pageSize: pageSize, #pageToken: pageToken, #onDebug: onDebug}),
      returnValue: Future.value(ListSourcesResponse(sources: [], nextPageToken: null)),
    );
  }
}

void main() {
  group('SourceProvider', () {
    late SourceProvider provider;
    late MockJulesClient mockClient;

    setUp(() {
      provider = SourceProvider();
      mockClient = MockJulesClient();
    });

    test('loadInitialPage loads data successfully', () async {
      final sources = <Source>[
        Source(name: 'source1', id: 'id1'),
        Source(name: 'source2', id: 'id2'),
      ];
      final response = ListSourcesResponse(sources: sources, nextPageToken: 'next_page');

      when(mockClient.listSources()).thenAnswer((_) async => response);

      await provider.loadInitialPage(mockClient);

      expect(provider.sources, equals(sources));
      expect(provider.currentPage, 1);
      expect(provider.hasMorePages, true);
      expect(provider.initialLoadComplete, true);
      expect(provider.error, isNull);
    });

    test('loadInitialPage handles errors', () async {
      when(mockClient.listSources()).thenThrow(Exception('Network error'));

      await provider.loadInitialPage(mockClient);

      expect(provider.sources, isEmpty);
      expect(provider.initialLoadComplete, false);
      expect(provider.error, contains('Network error'));
    });

    test('loadNextPage appends data', () async {
      // Setup initial state
      final initialSources = <Source>[Source(name: 'source1', id: 'id1')];
      final initialResponse = ListSourcesResponse(sources: initialSources, nextPageToken: 'token1');
      when(mockClient.listSources()).thenAnswer((_) async => initialResponse);
      await provider.loadInitialPage(mockClient);

      // Setup next page
      final nextSources = <Source>[Source(name: 'source2', id: 'id2')];
      final nextResponse = ListSourcesResponse(sources: nextSources, nextPageToken: null);
      when(mockClient.listSources(pageToken: 'token1')).thenAnswer((_) async => nextResponse);

      await provider.loadNextPage(mockClient);

      expect(provider.sources.length, 2);
      expect(provider.sources[1].name, 'source2');
      expect(provider.currentPage, 2);
      expect(provider.hasMorePages, false);
    });

    test('refresh replaces data', () async {
      // Setup initial state
      final initialSources = <Source>[Source(name: 'old_source', id: 'id1')];
      final initialResponse = ListSourcesResponse(sources: initialSources, nextPageToken: null);
      when(mockClient.listSources()).thenAnswer((_) async => initialResponse);
      await provider.loadInitialPage(mockClient);

      // Setup refresh data
      final newSources = <Source>[Source(name: 'new_source', id: 'id2')];
      final newResponse = ListSourcesResponse(sources: newSources, nextPageToken: null);
      // Reset mock to return new data on next call (which refresh will do)
      // Note: refresh loops through pages. Here we just return one page.
      when(mockClient.listSources(pageToken: null)).thenAnswer((_) async => newResponse);

      await provider.refresh(mockClient);

      expect(provider.sources.length, 1);
      expect(provider.sources.first.name, 'new_source');
      expect(provider.initialLoadComplete, true);
    });
  });
}
