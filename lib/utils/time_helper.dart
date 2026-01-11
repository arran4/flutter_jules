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
  final timeStr = timeFilter.field == TimeFilterField.created
      ? session.createTime
      : session.updateTime;
  if (timeStr == null) return false;
  final sessionTime = DateTime.tryParse(timeStr);
  if (sessionTime == null) return false;

  final now = DateTime.now();

  if (timeFilter.type == TimeFilterType.between) {
    if (timeFilter.specificTime != null && timeFilter.specificTimeEnd != null) {
      return sessionTime.isAfter(timeFilter.specificTime!) &&
          sessionTime.isBefore(timeFilter.specificTimeEnd!);
    }
    return false;
  }

  if (timeFilter.specificTime != null) {
    if (timeFilter.type == TimeFilterType.newerThan) {
      return sessionTime.isAfter(timeFilter.specificTime!);
    } else {
      return sessionTime.isBefore(timeFilter.specificTime!);
    }
  }

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
    return sessionTime.isAfter(cutoff);
  } else {
    return sessionTime.isBefore(cutoff);
  }
}
