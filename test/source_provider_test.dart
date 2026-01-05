import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:jules_client/services/source_provider.dart';
import 'package:jules_client/services/jules_client.dart';
import 'package:jules_client/models/source.dart';
import 'package:jules_client/models/api_exchange.dart';

// Mock JulesClient
class MockJulesClient extends Mock implements JulesClient {
  @override
  Future<ListSourcesResponse> listSources(
      {int? pageSize, String? pageToken, void Function(ApiExchange)? onDebug}) {
    return super.noSuchMethod(
      Invocation.method(#listSources, [],
          {#pageSize: pageSize, #pageToken: pageToken, #onDebug: onDebug}),
      returnValue:
          Future.value(ListSourcesResponse(sources: [], nextPageToken: null)),
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

    test('fetchSources loads data successfully (single page)', () async {
      final sources = <Source>[
        Source(name: 'source1', id: 'id1'),
        Source(name: 'source2', id: 'id2'),
      ];
      final response =
          ListSourcesResponse(sources: sources, nextPageToken: null);

      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenAnswer((_) async => response);

      await provider.fetchSources(mockClient);

      expect(provider.items.length, 2);
      expect(provider.items[0].data.name, 'source1');
      expect(provider.items[1].data.name, 'source2');
      expect(provider.error, isNull);
    });

    test('fetchSources handles errors', () async {
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenThrow(Exception('Network error'));

      await provider.fetchSources(mockClient);

      expect(provider.items, isEmpty);
      expect(provider.error, contains('Network error'));
    });

    test('fetchSources handles pagination', () async {
      // Setup page 1
      final page1Sources = <Source>[Source(name: 'source1', id: 'id1')];
      final page1Response =
          ListSourcesResponse(sources: page1Sources, nextPageToken: 'token1');
      
      // Setup page 2
      final page2Sources = <Source>[Source(name: 'source2', id: 'id2')];
      final page2Response =
          ListSourcesResponse(sources: page2Sources, nextPageToken: null);

      // Mock sequence
      when(mockClient.listSources(pageToken: argThat(isNull, named: 'pageToken')))
          .thenAnswer((_) async => page1Response);
      when(mockClient.listSources(pageToken: argThat(equals('token1'), named: 'pageToken')))
          .thenAnswer((_) async => page2Response);

      await provider.fetchSources(mockClient);

      expect(provider.items.length, 2);
      expect(provider.items[0].data.name, 'source1');
      expect(provider.items[1].data.name, 'source2');
    });

    test('ensureSourceAvailable triggers fetch if source missing', () async {
        // Initial state empty
        final initialResponse = ListSourcesResponse(sources: [], nextPageToken: null);
        when(mockClient.listSources(pageToken: anyNamed('pageToken')))
            .thenAnswer((_) async => initialResponse);
        
        await provider.ensureSourceAvailable(mockClient, 'missing_source');
        
        // Should have called listSources (via fetchSources)
        verify(mockClient.listSources(pageToken: anyNamed('pageToken'))).called(1);
    });
  });
}
