class TimeParser {
  static DateTime? parse(String input) {
    input = input.toLowerCase().trim();
    final now = DateTime.now();

    // Duration-based phrases (e.g., "last 24 hours")
    final durationMatch = RegExp(r'last (\d+) (hours|days|weeks|months|years)').firstMatch(input);
    if (durationMatch != null) {
      final value = int.parse(durationMatch.group(1)!);
      final unit = durationMatch.group(2)!;
      switch (unit) {
        case 'hours':
          return now.subtract(Duration(hours: value));
        case 'days':
          return now.subtract(Duration(days: value));
        case 'weeks':
          return now.subtract(Duration(days: value * 7));
        case 'months':
          return DateTime(now.year, now.month - value, now.day);
        case 'years':
          return DateTime(now.year - value, now.month, now.day);
      }
    }

    // Relative time phrases
    if (input.contains('yesterday')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (input.contains('today')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (input.contains('tomorrow')) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (input.contains('last week')) {
      return now.subtract(const Duration(days: 7));
    }
    if (input.contains('last month')) {
      return DateTime(now.year, now.month - 1, now.day);
    }
    if (input.contains('last year')) {
      return DateTime(now.year - 1, now.month, now.day);
    }

    // Day of the week (e.g., "since wednesday")
    const dayOfWeekMap = {
      'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7
    };
    for (var day in dayOfWeekMap.keys) {
      if (input.contains(day)) {
        var dayOfWeek = dayOfWeekMap[day]!;
        var daysAgo = now.weekday - dayOfWeek;
        if (daysAgo < 0) {
          daysAgo += 7;
        }
        return now.subtract(Duration(days: daysAgo));
      }
    }

    // Absolute date and time formats
    try {
      return DateTime.parse(input);
    } catch (e) {
      // Ignore parsing errors and try other formats
    }

    // Month names (e.g., "since march")
    const monthMap = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
      'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
    };

    for (var month in monthMap.keys) {
      if (input.contains(month)) {
        var monthOfYear = monthMap[month]!;
        if (monthOfYear > now.month) {
          return DateTime(now.year - 1, monthOfYear);
        }
        return DateTime(now.year, monthOfYear);
      }
    }

    return null;
  }
}
