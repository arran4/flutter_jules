import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/services/session_provider.dart';

void main() {
  group('SessionProvider', () {
    late SessionProvider sessionProvider;

    setUp(() {
      sessionProvider = SessionProvider();
    });

    group('parsePrUrl', () {
      test('should parse a standard GitHub URL', () {
        final result = sessionProvider
            .parsePrUrl('https://github.com/owner/repo/pull/123');
        expect(result, isNotNull);
        expect(result!.owner, 'owner');
        expect(result.repo, 'repo');
        expect(result.prNumber, '123');
      });

      test('should parse a GitHub Enterprise URL with extra path segments', () {
        final result = sessionProvider.parsePrUrl(
            'https://github.example.com/org/owner/repo/pull/123');
        expect(result, isNotNull);
        expect(result!.owner, 'owner');
        expect(result.repo, 'repo');
        expect(result.prNumber, '123');
      });

      test('should return null for an invalid URL', () {
        final result =
            sessionProvider.parsePrUrl('https://github.com/owner/repo/pull');
        expect(result, isNull);
      });

      test('should return null for a URL without a pull request number', () {
        final result =
            sessionProvider.parsePrUrl('https://github.com/owner/repo/pull/');
        expect(result, isNull);
      });

      test('should return null for a URL with a trailing slash', () {
        final result = sessionProvider
            .parsePrUrl('https://github.com/owner/repo/pull/123/');
        expect(result, isNotNull);
        expect(result!.owner, 'owner');
        expect(result.repo, 'repo');
        expect(result.prNumber, '123');
      });

      test('should return null for a non-GitHub URL', () {
        final result =
            sessionProvider.parsePrUrl('https://example.com/owner/repo/pull/123');
        expect(result, isNull);
      });
    });
  });
}
