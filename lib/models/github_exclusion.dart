import 'package:dartobjectutils/dartobjectutils.dart';

enum GithubExclusionType { org, repo, pullRequest }

class GithubExclusion {
  final GithubExclusionType type;
  final String value;
  final String reason;
  final DateTime date;

  GithubExclusion({
    required this.type,
    required this.value,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'value': value,
        'reason': reason,
        'date': date.toIso8601String(),
      };

  factory GithubExclusion.fromJson(Map<String, dynamic> json) {
    return GithubExclusion(
      type: GithubExclusionType.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            getStringPropOrDefault(json, 'type', null),
        orElse: () => GithubExclusionType.repo,
      ),
      value: getStringPropOrThrow(json, 'value'),
      reason: getStringPropOrThrow(json, 'reason'),
      date: DateTime.parse(getStringPropOrThrow(json, 'date')),
    );
  }
}
