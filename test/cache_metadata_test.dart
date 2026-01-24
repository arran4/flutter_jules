import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/cache_metadata.dart';

void main() {
  group('CacheMetadata', () {
    test('serialization with reasonForLastUnread', () {
      final now = DateTime.now();
      final metadata = CacheMetadata(
        firstSeen: now,
        lastRetrieved: now,
        reasonForLastUnread: 'Test Reason',
      );

      final json = metadata.toJson();
      expect(json['reasonForLastUnread'], 'Test Reason');

      final deserialized = CacheMetadata.fromJson(json);
      expect(deserialized.reasonForLastUnread, 'Test Reason');
      expect(deserialized.firstSeen, now);
    });

    test('serialization without reasonForLastUnread', () {
      final now = DateTime.now();
      final metadata = CacheMetadata(
        firstSeen: now,
        lastRetrieved: now,
      );

      final json = metadata.toJson();
      expect(json.containsKey('reasonForLastUnread'), false);

      final deserialized = CacheMetadata.fromJson(json);
      expect(deserialized.reasonForLastUnread, null);
    });

    test('copyWith updates reasonForLastUnread', () {
      final now = DateTime.now();
      final metadata = CacheMetadata(
        firstSeen: now,
        lastRetrieved: now,
        reasonForLastUnread: 'Old Reason',
      );

      final updated = metadata.copyWith(reasonForLastUnread: 'New Reason');
      expect(updated.reasonForLastUnread, 'New Reason');
      expect(updated.firstSeen, now);

      // Verify original is unchanged
      expect(metadata.reasonForLastUnread, 'Old Reason');
    });

    test('copyWith preserves reasonForLastUnread if not provided', () {
       final now = DateTime.now();
      final metadata = CacheMetadata(
        firstSeen: now,
        lastRetrieved: now,
        reasonForLastUnread: 'Reason',
      );

      final updated = metadata.copyWith(isWatched: true);
      expect(updated.reasonForLastUnread, 'Reason');
      expect(updated.isWatched, true);
    });
  });
}
