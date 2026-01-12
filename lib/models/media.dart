import 'package:dartobjectutils/dartobjectutils.dart';

class Media {
  final String data;
  final String mimeType;
  Media({required this.data, required this.mimeType});
  factory Media.fromJson(Map<String, dynamic> json) => Media(
        data: getStringPropOrThrow(json, 'data'),
        mimeType: getStringPropOrThrow(json, 'mimeType'),
      );
  Map<String, dynamic> toJson() => {'data': data, 'mimeType': mimeType};
}
