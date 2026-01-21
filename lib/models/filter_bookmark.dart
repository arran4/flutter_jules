import 'package:dartobjectutils/dartobjectutils.dart';
import 'search_filter.dart';
import 'filter_element.dart';
import 'filter_expression_parser.dart';

class FilterBookmark {
  final String name;
  final String? description;
  final String expression;
  final List<SortOption> sorts;

  FilterBookmark({
    required this.name,
    this.description,
    required this.expression,
    required this.sorts,
  });

  /// Get the filter tree parsed from the expression
  FilterElement? get tree {
    if (expression.isEmpty) return null;
    return FilterExpressionParser.parse(expression);
  }

  factory FilterBookmark.fromJson(Map<String, dynamic> json) {
    String expression = getStringPropOrDefault(json, 'expression', '');

    // Support new 'expression' key
    if (expression.isEmpty &&
        json.containsKey('filterTree') &&
        json['filterTree'] != null) {
      // Temporary backward compatibility during migration if json is still on disk
      try {
        final tree = FilterElement.fromJson(
          json['filterTree'] as Map<String, dynamic>,
        );
        expression = tree.toExpression();
      } catch (_) {}
    }

    return FilterBookmark(
      name: getStringPropOrThrow(json, 'name'),
      description: getStringPropOrDefault(json, 'description', null),
      expression: expression,
      sorts: getObjectArrayPropOrDefaultFunction(
        json,
        'sorts',
        _sortOptionFromJson,
        () => [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'expression': expression,
      'sorts': sorts.map((s) => _sortOptionToJson(s)).toList(),
    };
  }

  FilterBookmark copyWith({
    String? name,
    String? description,
    String? expression,
    List<SortOption>? sorts,
  }) {
    return FilterBookmark(
      name: name ?? this.name,
      description: description ?? this.description,
      expression: expression ?? this.expression,
      sorts: sorts ?? this.sorts,
    );
  }
}

// Private helper functions for SortOption serialization
Map<String, dynamic> _sortOptionToJson(SortOption option) {
  return {'field': option.field.name, 'direction': option.direction.name};
}

SortOption _sortOptionFromJson(Map<String, dynamic> json) {
  final fieldName = getStringPropOrThrow(json, 'field');
  final field = SortField.values.firstWhere((e) => e.name == fieldName);

  final directionName = getStringPropOrThrow(json, 'direction');
  final direction = SortDirection.values.firstWhere(
    (e) => e.name == directionName,
  );

  return SortOption(field, direction);
}
