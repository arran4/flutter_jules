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

    test('fetchSources loads data successfully', () async {
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

    test('fetchSources handles pagination automatically', () async {
      // Page 1
      final sources1 = <Source>[Source(name: 'source1', id: 'id1')];
      final response1 =
          ListSourcesResponse(sources: sources1, nextPageToken: 'token1');
      when(mockClient.listSources(pageToken: null))
          .thenAnswer((_) async => response1);

      // Page 2
      final sources2 = <Source>[Source(name: 'source2', id: 'id2')];
      final response2 =
          ListSourcesResponse(sources: sources2, nextPageToken: null);
      when(mockClient.listSources(pageToken: 'token1'))
          .thenAnswer((_) async => response2);

      await provider.fetchSources(mockClient);

      expect(provider.items.length, 2);
      expect(provider.items[0].data.name, 'source1');
      expect(provider.items[1].data.name, 'source2');
    });

    test('refresh forces reload', () async {
      // First load
      final sources1 = <Source>[Source(name: 'old_source', id: 'id1')];
      final response1 =
          ListSourcesResponse(sources: sources1, nextPageToken: null);
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenAnswer((_) async => response1);

      await provider.fetchSources(mockClient);
      expect(provider.items.first.data.name, 'old_source');

      // Second load (refresh)
      final sources2 = <Source>[Source(name: 'new_source', id: 'id2')];
      final response2 =
          ListSourcesResponse(sources: sources2, nextPageToken: null);
      when(mockClient.listSources(pageToken: anyNamed('pageToken')))
          .thenAnswer((_) async => response2);

      await provider.fetchSources(mockClient, force: true);

      expect(provider.items.length, 1);
      expect(provider.items.first.data.name, 'new_source');
    });
  });
}
