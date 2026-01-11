enum TimeFilterType { newerThan, olderThan }

enum TimeFilterUnit { hours, days, months }

class TimeFilter {
  final TimeFilterType type;
  final int value;
  final TimeFilterUnit unit;
  final DateTime? specificTime;

  TimeFilter({
    required this.type,
    required this.value,
    required this.unit,
    this.specificTime,
  });

  factory TimeFilter.fromJson(Map<String, dynamic> json) {
    return TimeFilter(
      type: TimeFilterType.values.byName(json['type']),
      value: json['value'],
      unit: TimeFilterUnit.values.byName(json['unit']),
      specificTime: json['specificTime'] != null
          ? DateTime.parse(json['specificTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
      'unit': unit.name,
      'specificTime': specificTime?.toIso8601String(),
    };
  }
}
