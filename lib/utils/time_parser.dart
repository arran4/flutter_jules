class TimeParser {
  static DateTime? parse(String input) {
    final range = parseRange(input);
    if (range != null) {
      return range.start;
    }
    return _parseDateTime(input);
  }

  static ({DateTime start, DateTime end})? parseRange(String input) {
    input = input.toLowerCase().trim();
    final now = DateTime.now();

    // Duration-based phrases (e.g., "last 24 hours")
    final durationMatch =
        RegExp(r'last (\d+) (hour|day|week|month|year)s?').firstMatch(input);
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
