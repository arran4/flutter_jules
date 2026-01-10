import 'search_filter.dart';
import 'enums.dart';
import 'filter_element.dart';
import 'filter_element_builder.dart';

class FilterBookmark {
  final String name;
  final String? description;

  // New format: single filter tree
  final FilterElement? filterTree;

  // Legacy support: flat filter list
  final List<FilterToken>? _legacyFilters;

  final List<SortOption> sorts;

  FilterBookmark({
    required this.name,
    this.description,
    this.filterTree,
    List<FilterToken>? filters,
    required this.sorts,
  }) : _legacyFilters = filters {
    // Ensure we have at least one format
    assert(filterTree != null || filters != null || (filters?.isEmpty ?? true),
        'FilterBookmark must have either filterTree or filters');
  }

  /// Get filters as a list (converts from tree if needed)
  List<FilterToken> get filters {
    if (_legacyFilters != null) {
      return _legacyFilters!;
    }
    if (filterTree != null) {
      return FilterElementBuilder.toFilterTokens(filterTree);
    }
    return [];
  }

  /// Get the filter tree (converts from list if needed)
  FilterElement? get tree {
    if (filterTree != null) {
      return filterTree;
    }
    if (_legacyFilters != null && _legacyFilters!.isNotEmpty) {
      return FilterElementBuilder.fromFilterTokens(_legacyFilters!);
    }
    return null;
  }

  /// Check if this bookmark uses the new tree format
  bool get usesTreeFormat => filterTree != null;

  factory FilterBookmark.fromJson(Map<String, dynamic> json) {
    // Check if this is new format (has 'filterTree' key) or old format (has 'filters' array)
    final hasTree =
        json.containsKey('filterTree') && json['filterTree'] != null;
    final hasFilters = json.containsKey('filters') && json['filters'] != null;

    FilterElement? tree;
    List<FilterToken>? legacyFilters;

    if (hasTree) {
      // New format
      try {
        tree =
            FilterElement.fromJson(json['filterTree'] as Map<String, dynamic>);
      } catch (e) {
        // If tree parsing fails, try to use filters as fallback
        if (hasFilters) {
          legacyFilters = _parseFiltersArray(json['filters'] as List<dynamic>);
        }
      }
    } else if (hasFilters) {
      // Legacy format
      legacyFilters = _parseFiltersArray(json['filters'] as List<dynamic>);
    }

    // Safely parse sorts
    final sortsList = json['sorts'] as List<dynamic>? ?? [];
    final parsedSorts = sortsList
        .map((s) {
          try {
            return _sortOptionFromJson(s as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .where((s) => s != null)
        .cast<SortOption>()
        .toList();

    return FilterBookmark(
      name: json['name'] as String,
      description: json['description'] as String?,
      filterTree: tree,
      filters: legacyFilters,
      sorts: parsedSorts,
    );
  }

  static List<FilterToken> _parseFiltersArray(List<dynamic> filtersList) {
    return filtersList
        .map((f) {
          try {
            return _filterTokenFromJson(f as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .where((f) => f != null)
        .cast<FilterToken>()
        .toList();
  }

  Map<String, dynamic> toJson() {
    // Always save in new format if we have a tree
    final Map<String, dynamic> result = {
      'name': name,
      'description': description,
      'sorts': sorts.map((s) => _sortOptionToJson(s)).toList(),
    };

    if (filterTree != null) {
      // New format
      result['filterTree'] = filterTree!.toJson();
    } else if (_legacyFilters != null && _legacyFilters!.isNotEmpty) {
      // Legacy format (only if no tree exists)
      result['filters'] =
          _legacyFilters!.map((f) => _filterTokenToJson(f)).toList();
    } else {
      // Empty filters
      result['filters'] = [];
    }

    return result;
  }

  /// Create a copy with updated values
  FilterBookmark copyWith({
    String? name,
    String? description,
    FilterElement? filterTree,
    List<FilterToken>? filters,
    List<SortOption>? sorts,
  }) {
    return FilterBookmark(
      name: name ?? this.name,
      description: description ?? this.description,
      filterTree: filterTree ?? this.filterTree,
      filters: filters ?? _legacyFilters,
      sorts: sorts ?? this.sorts,
    );
  }

  /// Migrate this bookmark to the new tree format
  FilterBookmark migrateToTree() {
    if (filterTree != null) {
      return this; // Already using tree format
    }

    if (_legacyFilters == null || _legacyFilters!.isEmpty) {
      return this; // No filters to migrate
    }

    final newTree = FilterElementBuilder.fromFilterTokens(_legacyFilters!);
    return FilterBookmark(
      name: name,
      description: description,
      filterTree: newTree,
      filters: null, // Clear legacy filters
      sorts: sorts,
    );
  }
}

// Private helper functions for FilterToken serialization
Map<String, dynamic> _filterTokenToJson(FilterToken token) {
  return {
    'id': token.id,
    'type': token.type.name,
    'label': token.label,
    'value': token.type == FilterType.status && token.value is SessionState
        ? (token.value as SessionState).name
        : token.value,
    'mode': token.mode.name,
  };
}

FilterToken _filterTokenFromJson(Map<String, dynamic> json) {
  final typeName = json['type'] as String;
  final type = FilterType.values.firstWhere((e) => e.name == typeName);

  dynamic value;
  if (type == FilterType.status) {
    final valueName = json['value'] as String;
    value = SessionState.values.firstWhere((e) => e.name == valueName);
  } else {
    value = json['value'];
  }

  final modeName = json['mode'] as String;
  final mode = FilterMode.values.firstWhere((e) => e.name == modeName);

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
  return {'field': option.field.name, 'direction': option.direction.name};
}

SortOption _sortOptionFromJson(Map<String, dynamic> json) {
  final fieldName = json['field'] as String;
  final field = SortField.values.firstWhere((e) => e.name == fieldName);

  final directionName = json['direction'] as String;
  final direction = SortDirection.values.firstWhere(
    (e) => e.name == directionName,
  );

  return SortOption(field, direction);
}
