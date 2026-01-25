import 'package:dartobjectutils/dartobjectutils.dart';

class SourceGroup {
  final String name;
  final List<String> sourceNames;

  SourceGroup({required this.name, required this.sourceNames});

  factory SourceGroup.fromJson(Map<String, dynamic> json) {
    return SourceGroup(
      name: getStringPropOrThrow(json, 'name'),
      sourceNames:
          getStringArrayPropOrDefault(json, 'sourceNames', <String>[]) ??
              <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'sourceNames': sourceNames};
  }
}
