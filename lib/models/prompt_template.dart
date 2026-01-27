import 'package:dartobjectutils/dartobjectutils.dart';

class PromptTemplate {
  final String id;
  final String name;
  final String? description;
  final String content;
  final bool isBuiltIn;

  PromptTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.content,
    this.isBuiltIn = false,
  });

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: getStringPropOrThrow(json, 'id'),
      name: getStringPropOrThrow(json, 'name'),
      description: getStringPropOrDefault(json, 'description', null),
      content: getStringPropOrThrow(json, 'content'),
      isBuiltIn: getBooleanPropOrDefault(json, 'isBuiltIn', false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'content': content,
      'isBuiltIn': isBuiltIn,
    };
  }
}
