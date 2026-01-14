import 'package:dartobjectutils/dartobjectutils.dart';

class Note {
  final String content;
  final String updatedDate;
  final int version;

  Note({
    required this.content,
    required this.updatedDate,
    required this.version,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      content: getStringPropOrThrow(json, 'content'),
      updatedDate: getStringPropOrThrow(json, 'updatedDate'),
      version: (getNumberPropOrThrow(json, 'version') as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'content': content, 'updatedDate': updatedDate, 'version': version};
  }
}
