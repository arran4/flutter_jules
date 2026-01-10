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

  /// Returns true if this element matches the given criteria
  bool evaluate(FilterContext context);

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
  Map<String, dynamic> toJson() => {
        'type': 'and',
        'children': children.map((c) => c.toJson()).toList(),
      };

  @override
  bool evaluate(FilterContext context) {
    return children.every((child) => child.evaluate(context));
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
  Map<String, dynamic> toJson() => {
        'type': 'or',
        'children': children.map((c) => c.toJson()).toList(),
      };

  @override
  bool evaluate(FilterContext context) {
    return children.any((child) => child.evaluate(context));
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
  Map<String, dynamic> toJson() => {
        'type': 'not',
        'child': child.toJson(),
      };

  @override
  bool evaluate(FilterContext context) {
    return !child.evaluate(context);
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
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'text': text,
      };

  @override
  bool evaluate(FilterContext context) {
    final query = text.toLowerCase();
    final session = context.session;
    return (session.title?.toLowerCase().contains(query) ?? false) ||
        (session.name.toLowerCase().contains(query)) ||
        (session.id.toLowerCase().contains(query)) ||
        (session.state.toString().toLowerCase().contains(query)) ||
        (session.prStatus?.toLowerCase().contains(query) ?? false) ||
        context.metadata.labels.any((l) => l.toLowerCase().contains(query));
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
  Map<String, dynamic> toJson() => {
        'type': 'pr_status',
        'label': label,
        'value': value,
      };

  @override
  bool evaluate(FilterContext context) {
    return context.session.prStatus?.toLowerCase() == value.toLowerCase();
  }

  factory PrStatusElement.fromJson(Map<String, dynamic> json) {
    return PrStatusElement(
      json['label'] as String,
      json['value'] as String,
    );
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
  Map<String, dynamic> toJson() => {
        'type': 'label',
        'label': label,
        'value': value,
      };

  @override
  bool evaluate(FilterContext context) {
    final metadata = context.metadata;
    final session = context.session;
    final queueProvider = context.queueProvider;

    if (value == 'new' && metadata.isNew) return true;
    if (value == 'updated' && metadata.isUpdated && !metadata.isNew) {
      return true;
    }
    if (value == 'unread' && metadata.isUnread) return true;
    if (value == 'has_pr' &&
        (session.outputs?.any((o) => o.pullRequest != null) ?? false)) {
      return true;
    }
    if (value == 'watched' && metadata.isWatched) return true;
    if (value == 'hidden' && metadata.isHidden) return true;
    if (value == 'draft') {
      if (queueProvider != null) {
        try {
          if (queueProvider.getDrafts(session.id).isNotEmpty) return true;
        } catch (_) {}
      }
      if (session.id.startsWith('DRAFT_CREATION_')) return true;
    }

    // Generic label matching
    if (metadata.labels.any((l) => l.toLowerCase() == value.toLowerCase())) {
      return true;
    }

    return false;
  }

  factory LabelElement.fromJson(Map<String, dynamic> json) {
    return LabelElement(
      json['label'] as String,
      json['value'] as String,
    );
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
  Map<String, dynamic> toJson() => {
        'type': 'status',
        'label': label,
        'value': value,
      };

  @override
  bool evaluate(FilterContext context) {
    return context.session.state.toString().toLowerCase() ==
            value.toLowerCase() ||
        (context.session.state?.name.toLowerCase() ?? '') ==
            value.toLowerCase();
  }

  factory StatusElement.fromJson(Map<String, dynamic> json) {
    return StatusElement(
      json['label'] as String,
      json['value'] as String,
    );
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
  Map<String, dynamic> toJson() => {
        'type': 'source',
        'label': label,
        'value': value,
      };

  @override
  bool evaluate(FilterContext context) {
    return context.session.sourceContext.source.toLowerCase() ==
        value.toLowerCase();
  }

  factory SourceElement.fromJson(Map<String, dynamic> json) {
    return SourceElement(
      json['label'] as String,
      json['value'] as String,
    );
  }
}

/// Has PR filter element
class HasPrElement extends FilterElement {
  HasPrElement();

  @override
  FilterElementType get type => FilterElementType.hasPr;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'has_pr',
      };

  @override
  bool evaluate(FilterContext context) {
    return context.session.outputs?.any((o) => o.pullRequest != null) ?? false;
  }

  factory HasPrElement.fromJson(Map<String, dynamic> json) {
    return HasPrElement();
  }
}
