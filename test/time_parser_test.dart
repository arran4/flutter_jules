import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/utils/time_parser.dart';

void main() {
  group('TimeParser', () {
    test('should parse relative time phrases', () {
      final now = DateTime.now();
      expect(TimeParser.parse('yesterday')?.day, now.day - 1);
      expect(TimeParser.parse('today')?.day, now.day);
      expect(TimeParser.parse('tomorrow')?.day, now.day + 1);
      expect(TimeParser.parse('last week')?.day, now.subtract(const Duration(days: 7)).day);
      expect(TimeParser.parse('last month')?.month, now.month - 1);
      expect(TimeParser.parse('last year')?.year, now.year - 1);
    });

    test('should parse absolute date and time formats', () {
      expect(TimeParser.parse('2023-10-27 10:00:00'), DateTime(2023, 10, 27, 10));
      expect(TimeParser.parse('2023-10-27'), DateTime(2023, 10, 27));
    });

    test('should parse month names', () {
      final now = DateTime.now();
      expect(TimeParser.parse('january')?.month, 1);
      expect(TimeParser.parse('february')?.month, 2);
      expect(TimeParser.parse('march')?.month, 3);
      expect(TimeParser.parse('april')?.month, 4);
      expect(TimeParser.parse('may')?.month, 5);
      expect(TimeParser.parse('june')?.month, 6);
      expect(TimeParser.parse('july')?.month, 7);
      expect(TimeParser.parse('august')?.month, 8);
      expect(TimeParser.parse('september')?.month, 9);
      expect(TimeParser.parse('october')?.month, 10);
      expect(TimeParser.parse('november')?.month, 11);
      expect(TimeParser.parse('december')?.month, 12);
    });

    test('should parse duration-based phrases', () {
      final now = DateTime.now();
      expect(TimeParser.parse('last 24 hours')?.hour, now.subtract(const Duration(hours: 24)).hour);
      expect(TimeParser.parse('last 7 days')?.day, now.subtract(const Duration(days: 7)).day);
    });

    test('should parse day of the week', () {
      final now = DateTime.now();
      final wednesday = TimeParser.parse('wednesday');
      expect(wednesday?.weekday, 3);
      if (now.weekday < 3) {
        expect(wednesday?.isBefore(now), isTrue);
      }
    });

    test('should return null for invalid input', () {
      expect(TimeParser.parse('invalid input'), isNull);
    });
  });
}
