import '../models/session.dart';
import '../models/time_filter.dart';
import 'time_parser.dart';

String timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 365) {
    return '${(difference.inDays / 365).floor()} years ago';
  } else if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} months ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} days ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hours ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} mins ago';
  } else {
    return 'Just now';
  }
}

String timeUntil(DateTime dateTime) {
  final now = DateTime.now();
  final difference = dateTime.difference(now);

  if (difference.isNegative) {
    return "Due";
  }

  if (difference.inDays > 365) {
    final years = (difference.inDays / 365).floor();
    return 'in $years ${years == 1 ? "year" : "years"}';
  } else if (difference.inDays > 30) {
    final months = (difference.inDays / 30).floor();
    return 'in $months ${months == 1 ? "month" : "months"}';
  } else if (difference.inDays > 0) {
    final days = difference.inDays;
    return 'in $days ${days == 1 ? "day" : "days"}';
  } else if (difference.inHours > 0) {
    final hours = difference.inHours;
    return 'in $hours ${hours == 1 ? "hour" : "hours"}';
  } else if (difference.inMinutes > 0) {
    final mins = difference.inMinutes;
    return 'in $mins ${mins == 1 ? "min" : "mins"}';
  } else {
    return 'in <1 min';
  }
}

bool matchesTimeFilter(Session session, TimeFilter timeFilter) {
  final timeStr = timeFilter.field == TimeFilterField.created
      ? session.createTime
      : session.updateTime;
  if (timeStr == null) return false;
  final sessionTime = DateTime.tryParse(timeStr);
  if (sessionTime == null) return false;

  if (timeFilter.specificTime != null) {
    switch (timeFilter.type) {
      case TimeFilterType.newerThan:
        return sessionTime.isAfter(timeFilter.specificTime!);
      case TimeFilterType.olderThan:
        return sessionTime.isBefore(timeFilter.specificTime!);
      case TimeFilterType.between:
      case TimeFilterType.inRange:
        return timeFilter.specificTimeEnd != null &&
            sessionTime.isAfter(timeFilter.specificTime!) &&
            sessionTime.isBefore(timeFilter.specificTimeEnd!);
    }
  }

  if (timeFilter.range != null) {
    if (timeFilter.type == TimeFilterType.between ||
        timeFilter.type == TimeFilterType.inRange) {
      final range = TimeParser.parseRange(timeFilter.range!);
      if (range == null) return false;
      return sessionTime.isAfter(range.start) &&
          sessionTime.isBefore(range.end);
    }
    final cutoff = TimeParser.parse(timeFilter.range!);
    if (cutoff == null) return false;
    if (timeFilter.type == TimeFilterType.newerThan) {
      return sessionTime.isAfter(cutoff);
    } else if (timeFilter.type == TimeFilterType.olderThan) {
      return sessionTime.isBefore(cutoff);
    }
  }

  return false;
}
