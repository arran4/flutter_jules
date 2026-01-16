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
      name: json['name'] as String,
      description: json['description'] as String?,
      filterExpression: json['filterExpression'] as String,
      actionScript: json['actionScript'] as String,
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
