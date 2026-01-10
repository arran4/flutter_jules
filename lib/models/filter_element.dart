import 'session.dart';
import 'cache_metadata.dart';

enum FilterElementType {
  and,
  or,
  not,
  text,
  label,
  status,
  source,
  hasPr,
  prStatus,
  branch,
}

enum FilterState {
  explicitOut(-2),
  implicitOut(-1),
  implicitIn(1),
  explicitIn(2);

  final int value;
  const FilterState(this.value);

  int get priority => value.abs();
  bool get isIn => value > 0;
  bool get isExplicit => priority == 2;

  static FilterState combineAnd(FilterState a, FilterState b) {
    if (a.priority > b.priority) {
      return a;
    }
    if (b.priority > a.priority) {
      return b;
    }
    return a.value < b.value ? a : b;
  }

  static FilterState combineOr(FilterState a, FilterState b) {
    if (a.priority > b.priority) {
      return a;
    }
    if (b.priority > a.priority) {
      return b;
    }
    return a.value > b.value ? a : b;
  }

  FilterState negate() {
    switch (this) {
      case FilterState.explicitIn:
        return FilterState.explicitOut;
      case FilterState.implicitIn:
        return FilterState.implicitOut;
      case FilterState.implicitOut:
        return FilterState.implicitIn;
      case FilterState.explicitOut:
        return FilterState.explicitIn;
    }
  }
}

/// Context for evaluating filter elements
class FilterContext {
  final Session session;
  final CacheMetadata metadata;
  final dynamic
      queueProvider; // Using dynamic to avoid hard dependency on provider

  FilterContext({
    required this.session,
    required this.metadata,
    this.queueProvider,
  });
}

/// Base class for all filter elements
abstract class FilterElement {
  FilterElementType get type;

  Map<String, dynamic> toJson();

  /// The grouping type used to determine if elements should be combined with OR.
  /// Elements with the same groupingType are OR'd together.
  /// Elements with different groupingTypes are AND'd together.
  String get groupingType;

  /// Evaluates the element and returns the resulting FilterState
  FilterState evaluate(FilterContext context);

  /// Returns the string expression representation of this element
  String toExpression();

  static String _quote(String s) {
    if (s.isEmpty) return '()';
    // If it contains unbalanced parentheses or commas that might be misinterpreted,
    // or if it starts/ends with whitespace, we use the bracket quoting.
    // However, the user wants minimal brackets.
    // We'll only use brackets if the string contains ')' or ',' or starts/ends with whitespace.
    if (!s.contains(')') && !s.contains(',') && s.trim() == s) {
      return s;
    }
    return '(${s.replaceAll('\\', '\\\\').replaceAll(')', '\\)')})';
  }

  /// Factory method to create FilterElement from JSON
  static FilterElement fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'and':
        return AndElement.fromJson(json);
      case 'or':
        return OrElement.fromJson(json);
      case 'not':
        return NotElement.fromJson(json);
      case 'text':
        return TextElement.fromJson(json);
      case 'label':
        return LabelElement.fromJson(json);
      case 'status':
        return StatusElement.fromJson(json);
      case 'source':
        return SourceElement.fromJson(json);
      case 'has_pr':
        return HasPrElement.fromJson(json);
      case 'pr_status':
        return PrStatusElement.fromJson(json);
      case 'branch':
        return BranchElement.fromJson(json);
      default:
        throw Exception('Unknown filter element type: $type');
    }
  }
}

/// Composite element that applies AND logic to its children
class AndElement extends FilterElement {
  final List<FilterElement> children;

  AndElement(this.children);

  @override
  FilterElementType get type => FilterElementType.and;

  @override
  String get groupingType => 'composite_and';

  @override
  String toExpression() {
    return 'AND(${children.map((c) => c.toExpression()).join(' ')})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'and',
        'children': children.map((c) => c.toJson()).toList(),
      };

  @override
  FilterState evaluate(FilterContext context) {
    if (children.isEmpty) {
      return FilterState.implicitIn;
    }
    FilterState result = children.first.evaluate(context);
    for (int i = 1; i < children.length; i++) {
      result = FilterState.combineAnd(result, children[i].evaluate(context));
    }
    return result;
  }

  /// Factory to create from JSON
  factory AndElement.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>;
    return AndElement(
      childrenJson
          .map((c) => FilterElement.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Composite element that applies OR logic to its children
class OrElement extends FilterElement {
  final List<FilterElement> children;

  OrElement(this.children);

  @override
  FilterElementType get type => FilterElementType.or;

  @override
  String get groupingType => 'composite_or';

  @override
  String toExpression() {
    return 'OR(${children.map((c) => c.toExpression()).join(' ')})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'or',
        'children': children.map((c) => c.toJson()).toList(),
      };

  @override
  FilterState evaluate(FilterContext context) {
    if (children.isEmpty) {
      return FilterState.implicitIn;
    }
    FilterState result = children.first.evaluate(context);
    for (int i = 1; i < children.length; i++) {
      result = FilterState.combineOr(result, children[i].evaluate(context));
    }
    return result;
  }

  factory OrElement.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>;
    return OrElement(
      childrenJson
          .map((c) => FilterElement.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Composite element that negates its child
class NotElement extends FilterElement {
  final FilterElement child;

  NotElement(this.child);

  @override
  FilterElementType get type => FilterElementType.not;

  @override
  String get groupingType => 'composite_not';

  @override
  String toExpression() {
    return 'NOT(${child.toExpression()})';
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'not', 'child': child.toJson()};

  @override
  FilterState evaluate(FilterContext context) {
    return child.evaluate(context).negate();
  }

  factory NotElement.fromJson(Map<String, dynamic> json) {
    return NotElement(
      FilterElement.fromJson(json['child'] as Map<String, dynamic>),
    );
  }
}

/// Text search element
class TextElement extends FilterElement {
  final String text;

  TextElement(this.text);

  @override
  FilterElementType get type => FilterElementType.text;

  @override
  String get groupingType => 'text';

  @override
  String toExpression() {
    return 'TEXT(${FilterElement._quote(text)})';
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};

  @override
  FilterState evaluate(FilterContext context) {
    final query = text.toLowerCase();
    final session = context.session;
    final matches = (session.title?.toLowerCase().contains(query) ?? false) ||
        (session.name.toLowerCase().contains(query)) ||
        (session.id.toLowerCase().contains(query)) ||
        (session.state.toString().toLowerCase().contains(query)) ||
        (session.prStatus?.toLowerCase().contains(query) ?? false) ||
        context.metadata.labels.any((l) => l.toLowerCase().contains(query));

    if (context.metadata.isHidden) {
      return matches ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(json['text'] as String);
  }
}

/// PR Status filter element
class PrStatusElement extends FilterElement {
  final String label;
  final String value;

  PrStatusElement(this.label, this.value);

  @override
  FilterElementType get type => FilterElementType.prStatus;

  @override
  String get groupingType => 'pr_status';

  @override
  String toExpression() {
    return 'PR(${FilterElement._quote(value)})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pr_status',
        'label': label,
        'value': value,
      };

  @override
  FilterState evaluate(FilterContext context) {
    final matches =
        context.session.prStatus?.toLowerCase() == value.toLowerCase();
    if (context.metadata.isHidden) return FilterState.implicitOut;
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory PrStatusElement.fromJson(Map<String, dynamic> json) {
    return PrStatusElement(json['label'] as String, json['value'] as String);
  }
}

/// Label/Flag filter element (New, Updated, Unread, etc.)
class LabelElement extends FilterElement {
  final String label;
  final String value;

  LabelElement(this.label, this.value);

  @override
  FilterElementType get type => FilterElementType.label;

  @override
  String get groupingType {
    // Isolated types (force AND grouping by using distinct keys)
    if (value == 'hidden') return 'label:hidden';
    if (value == 'watched') return 'label:watched';

    // Group "queue" type labels (Drafts, Pending)
    if (value == 'draft' || value == 'pending') {
      return 'label:queue';
    }

    // Standard labels group together (New, Updated, Unread)
    return 'label:standard';
  }

  @override
  String toExpression() {
    final v = value.toLowerCase();
    switch (v) {
      case 'new':
        return 'New()';
      case 'updated':
        return 'Updated()';
      case 'unread':
        return 'Unread()';
      case 'hidden':
        return 'Hidden()';
      case 'watched':
        return 'Watching()';
      case 'pending':
        return 'Pending()';
      case 'draft':
        return 'Has(Drafts)';
      case 'has_pr':
        return 'Has(PR)';
      default:
        return 'Label(${FilterElement._quote(value)})';
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'label',
        'label': label,
        'value': value,
      };

  @override
  FilterState evaluate(FilterContext context) {
    bool matched = false;
    final v = value.toLowerCase();
    final metadata = context.metadata;
    final session = context.session;
    final queueProvider = context.queueProvider;

    // Special case for Hidden() flag - this is a conversion rule
    if (v == 'hidden' || v == 'hide') {
      return metadata.isHidden
          ? FilterState.explicitIn
          : FilterState.explicitOut;
    }

    if (v == 'new' && metadata.isNew) {
      matched = true;
    } else if (v == 'updated' && metadata.isUpdated && !metadata.isNew) {
      matched = true;
    } else if (v == 'unread' && metadata.isUnread) {
      matched = true;
    } else if (v == 'has_pr' &&
        (session.outputs?.any((o) => o.pullRequest != null) ?? false)) {
      matched = true;
    } else if (v == 'watched' && metadata.isWatched) {
      matched = true;
    } else if (v == 'pending' && metadata.hasPendingUpdates) {
      matched = true;
    } else if (v == 'approval_required' &&
        (session.requirePlanApproval ?? false)) {
      matched = true;
    } else if (v == 'no_approval' && !(session.requirePlanApproval ?? false)) {
      matched = true;
    } else if (v == 'draft') {
      if (queueProvider != null) {
        try {
          if (queueProvider.getDrafts(session.id).isNotEmpty) {
            matched = true;
          }
        } catch (_) {}
      }
      if (session.id.startsWith('DRAFT_CREATION_')) {
        matched = true;
      }
    } else {
      matched = metadata.labels.any(
        (l) => l.toLowerCase() == value.toLowerCase(),
      );
    }

    // Standard rule: can only see *In (Explicitly exclude otherwise)
    if (metadata.isHidden) {
      return matched ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matched ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory LabelElement.fromJson(Map<String, dynamic> json) {
    return LabelElement(json['label'] as String, json['value'] as String);
  }
}

/// Status filter element
class StatusElement extends FilterElement {
  final String label;
  final String value;

  StatusElement(this.label, this.value);

  @override
  FilterElementType get type => FilterElementType.status;

  @override
  String get groupingType => 'status';

  @override
  String toExpression() {
    String cleanValue = value;
    if (cleanValue.startsWith('SessionState.')) {
      cleanValue = cleanValue.substring(13);
    } else if (cleanValue.startsWith('State.')) {
      cleanValue = cleanValue.substring(6);
    }
    return 'State(${FilterElement._quote(cleanValue)})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'status',
        'label': label,
        'value': value,
      };

  @override
  FilterState evaluate(FilterContext context) {
    String cleanVal = value;
    if (cleanVal.startsWith('SessionState.')) cleanVal = cleanVal.substring(13);
    if (cleanVal.startsWith('State.')) cleanVal = cleanVal.substring(6);

    final query = cleanVal.toLowerCase();
    final state = context.session.state;
    if (state == null) {
      if (context.metadata.isHidden) {
        return FilterState.implicitOut;
      }
      return FilterState.explicitOut;
    }

    final matches = state.toString().toLowerCase() == query ||
        state.name.toLowerCase() == query ||
        state.displayName.toLowerCase() == query;

    if (context.metadata.isHidden) {
      return matches ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory StatusElement.fromJson(Map<String, dynamic> json) {
    return StatusElement(json['label'] as String, json['value'] as String);
  }
}

/// Source filter element
class SourceElement extends FilterElement {
  final String label;
  final String value;

  SourceElement(this.label, this.value);

  @override
  FilterElementType get type => FilterElementType.source;

  @override
  String get groupingType => 'source';

  @override
  String toExpression() {
    return 'Source(${FilterElement._quote(value)})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'source',
        'label': label,
        'value': value,
      };

  @override
  FilterState evaluate(FilterContext context) {
    final matches = context.session.sourceContext.source.toLowerCase() ==
        value.toLowerCase();
    if (context.metadata.isHidden) {
      return matches ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory SourceElement.fromJson(Map<String, dynamic> json) {
    return SourceElement(json['label'] as String, json['value'] as String);
  }
}

/// Has PR filter element
class HasPrElement extends FilterElement {
  HasPrElement();

  @override
  FilterElementType get type => FilterElementType.hasPr;

  @override
  String get groupingType => 'has_pr';

  @override
  String toExpression() {
    return 'Has(PR)';
  }

  @override
  Map<String, dynamic> toJson() => {'type': 'has_pr'};

  @override
  FilterState evaluate(FilterContext context) {
    final matches =
        context.session.outputs?.any((o) => o.pullRequest != null) ?? false;
    if (context.metadata.isHidden) {
      return matches ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory HasPrElement.fromJson(Map<String, dynamic> json) {
    return HasPrElement();
  }
}

/// Branch filter element
class BranchElement extends FilterElement {
  final String label;
  final String value;

  BranchElement(this.label, this.value);

  @override
  FilterElementType get type => FilterElementType.branch;

  @override
  String get groupingType => 'branch';

  @override
  String toExpression() {
    return 'Branch(${FilterElement._quote(value)})';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'branch',
        'label': label,
        'value': value,
      };

  @override
  FilterState evaluate(FilterContext context) {
    final branch =
        context.session.sourceContext.githubRepoContext?.startingBranch;
    final matches = branch?.toLowerCase() == value.toLowerCase();

    if (context.metadata.isHidden) {
      return matches ? FilterState.implicitOut : FilterState.explicitOut;
    }
    return matches ? FilterState.explicitIn : FilterState.explicitOut;
  }

  factory BranchElement.fromJson(Map<String, dynamic> json) {
    return BranchElement(
      json['label'] as String,
      json['value'] as String,
    );
  }
}
