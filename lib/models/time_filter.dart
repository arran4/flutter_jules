import 'package:dartobjectutils/dartobjectutils.dart';

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
    String? range = getStringPropOrDefault(json, 'range', null);
    if (json.containsKey('value') && json.containsKey('unit')) {
      // This is the old format. Convert it to a relative time string.
      final unit = getStringPropOrThrow(json, 'unit')!.replaceAll('s', '');
      final value = json['value'];
      range = 'last $value $unit';
    }

    final specificTimeStr = getStringPropOrDefault(json, 'specificTime', null);
    final specificTimeEndStr =
        getStringPropOrDefault(json, 'specificTimeEnd', null);
    final fieldStr = getStringPropOrDefault(json, 'field', null);

    return TimeFilter(
      type: TimeFilterType.values.byName(getStringPropOrThrow(json, 'type')),
      specificTime:
          specificTimeStr != null ? DateTime.parse(specificTimeStr) : null,
      specificTimeEnd: specificTimeEndStr != null
          ? DateTime.parse(specificTimeEndStr)
          : null,
      range: range,
      field: fieldStr != null
          ? TimeFilterField.values.byName(fieldStr)
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
