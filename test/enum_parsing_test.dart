import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/models/session.dart';

enum TestEnum { valueOne, valueTwo }

void main() {
  group('getEnumPropOrDefault', () {
    test('returns correct enum value for valid string', () {
      final json = {'test': 'valueOne'};
      final result = getEnumPropOrDefault(json, 'test', TestEnum.values, null);
      expect(result, TestEnum.valueOne);
    });

    test('returns default value for invalid string', () {
      final json = {'test': 'invalid'};
      final result = getEnumPropOrDefault(
          json, 'test', TestEnum.values, TestEnum.valueTwo);
      expect(result, TestEnum.valueTwo);
    });

    test('returns default value for missing key', () {
      final json = <String, dynamic>{};
      final result = getEnumPropOrDefault(
          json, 'test', TestEnum.values, TestEnum.valueOne);
      expect(result, TestEnum.valueOne);
    });

    test('returns default value for null value', () {
      final json = {'test': null};
      final result = getEnumPropOrDefault(
          json, 'test', TestEnum.values, TestEnum.valueTwo);
      expect(result, TestEnum.valueTwo);
    });

    test('returns default value for non-string value', () {
      final json = {'test': 123};
      final result = getEnumPropOrDefault(
          json, 'test', TestEnum.values, TestEnum.valueTwo);
      expect(result, TestEnum.valueTwo);
    });

    test('returns null when default is null and key missing (safety check)',
        () {
      final json = <String, dynamic>{};
      final result = getEnumPropOrDefault(json, 'test', TestEnum.values, null);
      expect(result, isNull);
    });
  });
}
