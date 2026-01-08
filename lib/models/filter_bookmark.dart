import 'search_filter.dart';
import 'enums.dart';

class FilterBookmark {
  final String name;
  final String? description;
  final List<FilterToken> filters;
  final List<SortOption> sorts;

  FilterBookmark({
    required this.name,
    this.description,
    required this.filters,
    required this.sorts,
  });

  factory FilterBookmark.fromJson(Map<String, dynamic> json) {
    // Safely parse filters
    final filtersList = json['filters'] as List<dynamic>? ?? [];
    final parsedFilters = filtersList
        .map((f) {
          try {
            return _filterTokenFromJson(f as Map<String, dynamic>);
          } catch (e) {
            // print("Error parsing filter token: $e");
            return null;
          }
        })
        .where((f) => f != null)
        .cast<FilterToken>()
        .toList();

    // Safely parse sorts
    final sortsList = json['sorts'] as List<dynamic>? ?? [];
    final parsedSorts = sortsList
        .map((s) {
          try {
            return _sortOptionFromJson(s as Map<String, dynamic>);
          } catch (e) {
            // print("Error parsing sort option: $e");
            return null;
          }
        })
        .where((s) => s != null)
        .cast<SortOption>()
        .toList();

    return FilterBookmark(
      name: json['name'] as String,
      description: json['description'] as String?,
      filters: parsedFilters,
      sorts: parsedSorts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'filters': filters.map((f) => _filterTokenToJson(f)).toList(),
      'sorts': sorts.map((s) => _sortOptionToJson(s)).toList(),
    };
  }
}

// Private helper functions for FilterToken serialization
Map<String, dynamic> _filterTokenToJson(FilterToken token) {
  return {
    'id': token.id,
    'type': token.type.name,
    'label': token.label,
    'value':
        token.type == FilterType.status && token.value is SessionState
            ? (token.value as SessionState).name
            : token.value,
    'mode': token.mode.name,
  };
}

FilterToken _filterTokenFromJson(Map<String, dynamic> json) {
  final typeName = json['type'] as String;
  final type =
      FilterType.values.firstWhere((e) => e.name == typeName);

  dynamic value;
  if (type == FilterType.status) {
    final valueName = json['value'] as String;
    value = SessionState.values
        .firstWhere((e) => e.name == valueName);
  } else {
    value = json['value'];
  }

  final modeName = json['mode'] as String;
  final mode =
      FilterMode.values.firstWhere((e) => e.name == modeName);

  return FilterToken(
    id: json['id'] as String,
    type: type,
    label: json['label'] as String,
    value: value,
    mode: mode,
  );
}

// Private helper functions for SortOption serialization
Map<String, dynamic> _sortOptionToJson(SortOption option) {
  return {
    'field': option.field.name,
    'direction': option.direction.name,
  };
}

SortOption _sortOptionFromJson(Map<String, dynamic> json) {
  final fieldName = json['field'] as String;
  final field =
      SortField.values.firstWhere((e) => e.name == fieldName);

  final directionName = json['direction'] as String;
  final direction = SortDirection.values
      .firstWhere((e) => e.name == directionName);

  return SortOption(
    field,
    direction,
  );
}
