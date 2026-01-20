import 'package:dartobjectutils/dartobjectutils.dart';

class BulkActionPreset {
  final String name;
  final String? description;
  final String filterExpression;
  final String actionScript;

  BulkActionPreset({
    required this.name,
    this.description,
    required this.filterExpression,
    required this.actionScript,
  });

  factory BulkActionPreset.fromJson(Map<String, dynamic> json) {
    return BulkActionPreset(
      name: getStringPropOrThrow(json, 'name'),
      description: getStringPropOrDefault(json, 'description', null),
      filterExpression: getStringPropOrThrow(json, 'filterExpression'),
      actionScript: getStringPropOrThrow(json, 'actionScript'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'filterExpression': filterExpression,
      'actionScript': actionScript,
    };
  }
}
