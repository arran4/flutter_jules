enum TimeFilterType { newerThan, olderThan, between }

enum TimeFilterUnit { hours, days, months }

class TimeFilter {
  final TimeFilterType type;
  final int value;
  final TimeFilterUnit unit;
  final DateTime? specificTime;
  final DateTime? specificTimeEnd;

  TimeFilter({
    required this.type,
    this.value = 0,
    this.unit = TimeFilterUnit.days,
    this.specificTime,
    this.specificTimeEnd,
  });

  factory TimeFilter.fromJson(Map<String, dynamic> json) {
    return TimeFilter(
      type: TimeFilterType.values.byName(json['type']),
      value: json['value'],
      unit: TimeFilterUnit.values.byName(json['unit']),
      specificTime: json['specificTime'] != null
          ? DateTime.parse(json['specificTime'])
          : null,
      specificTimeEnd: json['specificTimeEnd'] != null
          ? DateTime.parse(json['specificTimeEnd'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
      'unit': unit.name,
      'specificTime': specificTime?.toIso8601String(),
      'specificTimeEnd': specificTimeEnd?.toIso8601String(),
    };
  }
}
