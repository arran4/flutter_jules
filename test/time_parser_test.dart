import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_jules/utils/time_parser.dart';

void main() {
  group('TimeParser', () {
    test('should parse relative time phrases', () {
      final now = DateTime.now();
      expect(TimeParser.parse('yesterday')?.day, now.day - 1);
      expect(TimeParser.parse('today')?.day, now.day);
      expect(TimeParser.parse('tomorrow')?.day, now.day + 1);
      expect(
        TimeParser.parse('last week')?.day,
        now.subtract(const Duration(days: 7)).day,
      );

      final expectedMonth = now.month == 1 ? 12 : now.month - 1;
      expect(TimeParser.parse('last month')?.month, expectedMonth);

      expect(TimeParser.parse('last year')?.year, now.year - 1);
    });

    test('should parse absolute date and time formats', () {
      expect(
        TimeParser.parse('2023-10-27 10:00:00'),
        DateTime(2023, 10, 27, 10),
      );
      expect(TimeParser.parse('2023-10-27'), DateTime(2023, 10, 27));
    });

    test('should parse month names', () {
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
      expect(
        TimeParser.parse('last 24 hours')?.hour,
        now.subtract(const Duration(hours: 24)).hour,
      );
      expect(
        TimeParser.parse('last 7 days')?.day,
        now.subtract(const Duration(days: 7)).day,
      );
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

    test('should parse various duration strings correctly', () {
      final now = DateTime(2024, 3, 31, 10, 0, 0);
      final testCases = {
        '1 hour': DateTime(2024, 3, 31, 9, 0, 0),
        '2 days': DateTime(2024, 3, 29, 10, 0, 0),
        '3 weeks': DateTime(2024, 3, 10, 10, 0, 0),
        '1 year': DateTime(2023, 3, 31, 10, 0, 0),
        '1 hour and 30 minutes': DateTime(2024, 3, 31, 8, 30, 0),
        '2 years, 3 months and 4 days': DateTime(2021, 12, 27, 10, 0, 0),
        '1 month ago': DateTime(2024, 2, 29, 10, 0, 0),
      };

      testCases.forEach((input, expected) {
        final result = TimeParser.parse(input, now: now)!;
        expect(result, expected);
      });
    });

    test('should handle month-end and leap-year edge cases', () {
      final testCases = [
        // March 31 -> Feb 29 (leap year)
        {
          'now': DateTime(2024, 3, 31),
          'input': '1 month',
          'expected': DateTime(2024, 2, 29),
        },
        // March 31 -> Feb 28 (non-leap year)
        {
          'now': DateTime(2023, 3, 31),
          'input': '1 month',
          'expected': DateTime(2023, 2, 28),
        },
        // May 31 -> April 30
        {
          'now': DateTime(2023, 5, 31),
          'input': '1 month',
          'expected': DateTime(2023, 4, 30),
        },
      ];

      for (var tc in testCases) {
        final result = TimeParser.parse(
          tc['input'] as String,
          now: tc['now'] as DateTime,
        )!;
        final expected = tc['expected'] as DateTime;
        expect(result.year, expected.year);
        expect(result.month, expected.month);
        expect(result.day, expected.day);
      }
    });
  });
}
