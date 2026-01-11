import '../models/session.dart';
import '../models/time_filter.dart';

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

bool matchesTimeFilter(Session session, TimeFilter timeFilter) {
  if (session.updateTime == null) return false;
  final sessionTime = DateTime.tryParse(session.updateTime!);
  if (sessionTime == null) return false;

  final now = DateTime.now();
  bool matches = false;

  if (timeFilter.specificTime != null) {
    if (timeFilter.type == TimeFilterType.newerThan) {
      matches = sessionTime.isAfter(timeFilter.specificTime!);
    } else {
      matches = sessionTime.isBefore(timeFilter.specificTime!);
    }
  } else {
    Duration duration;
    switch (timeFilter.unit) {
      case TimeFilterUnit.hours:
        duration = Duration(hours: timeFilter.value);
        break;
      case TimeFilterUnit.days:
        duration = Duration(days: timeFilter.value);
        break;
      case TimeFilterUnit.months:
        duration = Duration(days: timeFilter.value * 30); // Approximation
        break;
    }

    final cutoff = now.subtract(duration);
    if (timeFilter.type == TimeFilterType.newerThan) {
      matches = sessionTime.isAfter(cutoff);
    } else {
      matches = sessionTime.isBefore(cutoff);
    }
  }

  return matches;
}
