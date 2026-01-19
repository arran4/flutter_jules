enum GithubExclusionType {
  org,
  repo,
  pr,
}

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
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => GithubExclusionType.repo,
      ),
      value: json['value'] as String,
      reason: json['reason'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
