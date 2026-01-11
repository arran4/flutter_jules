import 'package:dartobjectutils/dartobjectutils.dart';

class Metadata {
  final String key;
  final String value;
  final String updatedDate;

  Metadata({
    required this.key,
    required this.value,
    required this.updatedDate,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      key: getStringPropOrThrow(json, 'key'),
      value: getStringPropOrThrow(json, 'value'),
      updatedDate: getStringPropOrThrow(json, 'updatedDate'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'updatedDate': updatedDate,
    };
  }
}
