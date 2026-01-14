enum TimeFilterField { created, updated }

enum TimeFilterType { newerThan, olderThan, between, inRange }

class TimeFilter {
  final TimeFilterType type;
  final DateTime? specificTime;
  final DateTime? specificTimeEnd;
  final String? range;
  final TimeFilterField field;

  TimeFilter({
    required this.type,
    this.specificTime,
    this.specificTimeEnd,
    this.range,
    this.field = TimeFilterField.updated,
  });

  factory TimeFilter.fromJson(Map<String, dynamic> json) {
    String? range = json['range'];
    if (json.containsKey('value') && json.containsKey('unit')) {
      // This is the old format. Convert it to a relative time string.
      final unit = (json['unit'] as String).replaceAll('s', '');
      range = 'last ${json['value']} $unit';
    }

    return TimeFilter(
      type: TimeFilterType.values.byName(json['type']),
      specificTime: json['specificTime'] != null
          ? DateTime.parse(json['specificTime'])
          : null,
      specificTimeEnd: json['specificTimeEnd'] != null
          ? DateTime.parse(json['specificTimeEnd'])
          : null,
      range: range,
      field: json['field'] != null
          ? TimeFilterField.values.byName(json['field'])
          : TimeFilterField.updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'specificTime': specificTime?.toIso8601String(),
      'specificTimeEnd': specificTimeEnd?.toIso8601String(),
      'range': range,
      'field': field.name,
    };
  }
}
