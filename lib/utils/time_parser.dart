class TimeParser {
  static DateTime? parse(String input, {DateTime? now}) {
    now ??= DateTime.now();
    // First check for complex range phrases like "last week"
    final range = parseRange(input, now: now);
    if (range != null) {
      return range.start;
    }

    input = input.toLowerCase().trim();
    // Regex to find all number-unit pairs, e.g., "1 hour", "3 minutes"
    final regex = RegExp(r'(\d+)\s+(year|month|week|day|hour|minute|second)s?');
    final durationMatches = regex.allMatches(input);

    if (durationMatches.isNotEmpty) {
      // To avoid parsing sentences, check if the string only contains duration parts and separators.
      String tempInput = input.replaceAll(regex, '').trim();
      tempInput = tempInput.replaceAll('and', '').replaceAll(',', '').trim();
      tempInput = tempInput.replaceAll('ago', '').trim();

      if (tempInput.isEmpty) {
        Duration duration = Duration.zero;
        int months = 0;
        int years = 0;

        for (final match in durationMatches) {
          final value = int.parse(match.group(1)!);
          final unit = match.group(2)!;

          switch (unit) {
            case 'year':
              years += value;
              break;
            case 'month':
              months += value;
              break;
            case 'week':
              duration += Duration(days: value * 7);
              break;
            case 'day':
              duration += Duration(days: value);
              break;
            case 'hour':
              duration += Duration(hours: value);
              break;
            case 'minute':
              duration += Duration(minutes: value);
              break;
            case 'second':
              duration += Duration(seconds: value);
              break;
          }
        }

        // To safely subtract months and years, we need to handle date rollovers.
        int newYear = now.year - years;
        int newMonth = now.month - months;
        int newDay = now.day;

        // Adjust month and year if newMonth is zero or negative
        while (newMonth <= 0) {
          newYear--;
          newMonth += 12;
        }

        // Check if the day exists in the new month and adjust if necessary
        final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        if (newDay > daysInNewMonth) {
          newDay = daysInNewMonth;
        }

        DateTime result = DateTime(
          newYear,
          newMonth,
          newDay,
          now.hour,
          now.minute,
          now.second,
        );
        result = result.subtract(duration);
        return result;
      }
    }

    // Finally, try to parse as a specific datetime
    return _parseDateTime(input);
  }

  static ({DateTime start, DateTime end})? parseRange(
    String input, {
    DateTime? now,
  }) {
    input = input.toLowerCase().trim();
    now ??= DateTime.now();

    // Duration-based phrases (e.g., "last 24 hours")
    final durationMatch = RegExp(
      r'last (\d+) (hour|day|week|month|year)s?',
    ).firstMatch(input);
    if (durationMatch != null) {
      final value = int.parse(durationMatch.group(1)!);
      final unit = durationMatch.group(2)!;
      DateTime start;
      switch (unit) {
        case 'hour':
          start = now.subtract(Duration(hours: value));
          break;
        case 'day':
          start = now.subtract(Duration(days: value));
          break;
        case 'week':
          start = now.subtract(Duration(days: value * 7));
          break;
        case 'month':
          start = DateTime(now.year, now.month - value, now.day);
          break;
        case 'year':
          start = DateTime(now.year - value, now.month, now.day);
          break;
        default:
          return null;
      }
      return (start: start, end: now);
    }

    // Relative time phrases
    if (input.contains('yesterday')) {
      final start = DateTime(now.year, now.month, now.day - 1);
      return (start: start, end: start.add(const Duration(days: 1)));
    }
    if (input.contains('today')) {
      final start = DateTime(now.year, now.month, now.day);
      return (start: start, end: start.add(const Duration(days: 1)));
    }
    if (input.contains('tomorrow')) {
      final start = DateTime(now.year, now.month, now.day + 1);
      return (start: start, end: start.add(const Duration(days: 1)));
    }
    if (input.contains('last week')) {
      final start = now.subtract(const Duration(days: 7));
      return (start: start, end: now);
    }
    if (input.contains('last month')) {
      final start = DateTime(now.year, now.month - 1, now.day);
      return (start: start, end: now);
    }
    if (input.contains('last year')) {
      final start = DateTime(now.year - 1, now.month, now.day);
      return (start: start, end: now);
    }

    // Day of the week (e.g., "since wednesday")
    const dayOfWeekMap = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    for (var day in dayOfWeekMap.keys) {
      if (input.contains(day)) {
        var dayOfWeek = dayOfWeekMap[day]!;
        var daysAgo = now.weekday - dayOfWeek;
        if (daysAgo <= 0) {
          daysAgo += 7;
        }
        final start = now.subtract(Duration(days: daysAgo));
        return (start: start, end: start.add(const Duration(days: 1)));
      }
    }

    // Month names (e.g., "since march")
    const monthMap = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    for (var month in monthMap.keys) {
      if (input.contains(month)) {
        var monthOfYear = monthMap[month]!;
        var year = now.year;
        if (monthOfYear > now.month) {
          year = now.year - 1;
        }
        final start = DateTime(year, monthOfYear);
        return (start: start, end: DateTime(year, monthOfYear + 1));
      }
    }

    return null;
  }

  static DateTime? _parseDateTime(String input) {
    try {
      return DateTime.parse(input);
    } catch (e) {
      // Ignore parsing errors and try other formats
    }
    return null;
  }
}
