enum FilterType {
  status,
  source,
  flag, // New, Updated, Unread
  text,
}

enum FilterMode {
  include, // Must match
  exclude, // Must NOT match
}

class FilterToken {
  final String id; // Unique ID for keying
  final FilterType type;
  final String label; // Display text
  final dynamic value; // Underlying value (e.g., SessionState enum)
  final FilterMode mode;

  FilterToken({
    required this.id,
    required this.type,
    required this.label,
    required this.value,
    this.mode = FilterMode.include,
  });

  FilterToken toggleMode() {
    return FilterToken(
      id: id,
      type: type,
      label: label,
      value: value,
      mode: mode == FilterMode.include
          ? FilterMode.exclude
          : FilterMode.include,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterToken &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          value == other.value &&
          mode == other.mode;

  @override
  int get hashCode =>
      id.hashCode ^ type.hashCode ^ value.hashCode ^ mode.hashCode;
}

enum SortField { updated, created, name, source, status }

enum SortDirection { ascending, descending }

class SortOption {
  final SortField field;
  final SortDirection direction;

  const SortOption(this.field, this.direction);

  String get label {
    switch (field) {
      case SortField.updated:
        return "Updated";
      case SortField.created:
        return "Created";
      case SortField.name:
        return "Name";
      case SortField.source:
        return "Source";
      case SortField.status:
        return "Status";
    }
  }
}
