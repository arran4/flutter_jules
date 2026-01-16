import 'package:dartobjectutils/dartobjectutils.dart';

class Metadata {
  final String key;
  final String value;
  final String updatedAt;

  Metadata({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      key: getStringPropOrThrow(json, 'key'),
      value: getStringPropOrThrow(json, 'value'),
      updatedAt: getStringPropOrThrow(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'value': value,
      'updatedAt': updatedAt,
    };
  }
}
